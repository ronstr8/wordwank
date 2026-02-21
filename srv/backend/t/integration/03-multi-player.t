use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games);

# Integration test for multi-player scenarios and game isolation
my $t = get_test_mojo();

cleanup_test_games($t);

subtest 'Multiple concurrent games with different languages' => sub {
    plan tests => 8;
    
    # Create players for English game
    my ($ws_en1, $p_en1) = create_ws_client(
        test_mojo => $t,
        nickname => 'English1',
        language => 'en',
    );
    
    my ($ws_en2, $p_en2) = create_ws_client(
        test_mojo => $t,
        nickname => 'English2',
        language => 'en',
    );
    
    # Create players for Spanish game (if different from English)
    my ($ws_es1, $p_es1) = create_ws_client(
        test_mojo => $t,
        nickname => 'Spanish1',
        language => 'es',
    );
    
    my ($ws_es2, $p_es2) = create_ws_client(
        test_mojo => $t,
        nickname => 'Spanish2',
        language => 'es',
    );
    
    ok($p_en1 && $p_en2 && $p_es1 && $p_es2, 'All players connected');
    
    # Get game states
    $ws_en1->message_ok; my $state_en1 = decode_json($ws_en1->message->[1]);
    $ws_en2->message_ok; my $state_en2 = decode_json($ws_en2->message->[1]);
    $ws_es1->message_ok; my $state_es1 = decode_json($ws_es1->message->[1]);
    $ws_es2->message_ok; my $state_es2 = decode_json($ws_es2->message->[1]);
    
    # English players should be in same game
    is($state_en1->{payload}{gameId}, $state_en2->{payload}{gameId},
       'English players in same game');
    
    # Spanish players should be in same game
    is($state_es1->{payload}{gameId}, $state_es2->{payload}{gameId},
       'Spanish players in same game');
    
    # The two games might be different
    diag("EN game: " . $state_en1->{payload}{gameId});
    diag("ES game: " . $state_es1->{payload}{gameId});
    
    $ws_en1->finish_ok;
    $ws_en2->finish_ok;
    $ws_es1->finish_ok;
    $ws_es2->finish_ok;
};

subtest 'Chat isolation between games' => sub {
    plan tests => 9;
    
    # Create two games with different languages
    my ($ws1, $p1) = create_ws_client(
        test_mojo => $t,
        nickname => 'GameA_Player',
        language => 'en',
    );
    
    my ($ws2, $p2) = create_ws_client(
        test_mojo => $t,
        nickname => 'GameB_Player',
        language => 'fr', # Different language = different game
    );
    
    ok($p1 && $p2, 'Both players connected');
    
    # Clear initial messages
    $ws1->message_ok; my $state1 = decode_json($ws1->message->[1]);
    $ws2->message_ok; my $state2 = decode_json($ws2->message->[1]);
    
    my $game1 = $state1->{payload}{gameId};
    my $game2 = $state2->{payload}{gameId};
    
    ok(defined $game1 && defined $game2, 'Both have game IDs');
    
    # Player 1 sends a chat in their game
    my $chat1 = encode_json({
        type => 'chat',
        payload => { text => 'Secret message in game A' }
    });
    
    $ws1->send_ok($chat1);
    
    # Player 1 should receive their own message
    $ws1->message_ok('Player 1 got echo');
    my $echo = decode_json($ws1->message->[1]);
    is($echo->{payload}{text}, 'Secret message in game A', 'Echo correct');
    
    # Player 2 should NOT receive this message (different game)
    # Give it a moment to ensure no message arrives
    select(undef, undef, undef, 0.3);
    
    # Try to receive - should timeout or get nothing chat-related
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm 1;
        $ws2->message_ok;
        alarm 0;
        
        # If we got here, check if it's NOT a chat from player 1
        my $msg = decode_json($ws2->message->[1]);
        isnt($msg->{payload}{text}, 'Secret message in game A',
             'Player 2 did not receive Player 1\'s chat');
    };
    
    if ($@ eq "timeout\n") {
        pass('Player 2 received no message (correct isolation)');
    }
    
    $ws1->finish_ok;
    $ws2->finish_ok;
};

subtest 'Player disconnection handling' => sub {
    plan tests => 6;
    
    my ($ws1, $p1) = create_ws_client(
        test_mojo => $t,
        nickname => 'StayingPlayer',
    );
    
    my ($ws2, $p2) = create_ws_client(
        test_mojo => $t,
        nickname => 'LeavingPlayer',
    );
    
    ok($p1 && $p2, 'Both players connected');
    
    # Clear initial messages
    $ws1->message_ok;
    $ws2->message_ok;
    
    # Player 2 disconnects
    $ws2->finish_ok;
    
    # Player 1 should still be connected and functional
    my $chat = encode_json({
        type => 'chat',
        payload => { text => 'Anyone still here?' }
    });
    
    $ws1->send_ok($chat);
    
    # Should still receive own message
    $ws1->message_ok('Player 1 still functional after P2 disconnect');
    my $msg = decode_json($ws1->message->[1]);
    is($msg->{type}, 'chat', 'Still receiving chat messages');
    
    $ws1->finish_ok;
};

subtest 'Rapid connect-disconnect stress' => sub {
    plan tests => 10;
    
    # Rapidly create and destroy connections
    for my $i (1..5) {
        my ($ws, $pid) = create_ws_client(
            test_mojo => $t,
            nickname => "Rapid$i",
        );
        
        ok($pid, "Rapid connection $i successful");
        $ws->message_ok; # Clear game state
        $ws->finish_ok;
    }
};

cleanup_test_games($t);

done_testing();
