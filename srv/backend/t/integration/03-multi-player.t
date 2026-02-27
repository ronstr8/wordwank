use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games wait_for_message);

# Integration test for multi-player scenarios and game isolation
my $t = get_test_mojo();

cleanup_test_games($t);

subtest 'Multiple concurrent games with different languages' => sub {
    # Create players for English game
    my ($ws_en1, $p_en1, $g_en1) = create_ws_client(
        test_mojo => $t,
        nickname => 'English1',
        language => 'en',
    );
    
    my ($ws_en2, $p_en2, $g_en2) = create_ws_client(
        test_mojo => $t,
        nickname => 'English2',
        language => 'en',
    );
    
    # Create players for Spanish game (if different from English)
    my ($ws_es1, $p_es1, $g_es1) = create_ws_client(
        test_mojo => $t,
        nickname => 'Spanish1',
        language => 'es',
    );
    
    my ($ws_es2, $p_es2, $g_es2) = create_ws_client(
        test_mojo => $t,
        nickname => 'Spanish2',
        language => 'es',
    );
    
    ok($p_en1 && $p_en2 && $p_es1 && $p_es2, 'All players connected');
    
    # English players should be in same game
    is($g_en1->{gameId}, $g_en2->{gameId},
       'English players in same game');
    
    # Spanish players should be in same game
    is($g_es1->{gameId}, $g_es2->{gameId},
       'Spanish players in same game');
    
    # The two games might be different
    diag("EN game: " . $g_en1->{gameId});
    diag("ES game: " . $g_es1->{gameId});
    
    $ws_en1->finish_ok;
    $ws_en2->finish_ok;
    $ws_es1->finish_ok;
    $ws_es2->finish_ok;
    
    done_testing();
};

cleanup_test_games($t);

subtest 'Chat isolation between games' => sub {
    # Create two games with different languages
    my ($ws1, $p1, $g1) = create_ws_client(
        test_mojo => $t,
        nickname => 'GameA_Player',
        language => 'en',
    );
    
    my ($ws2, $p2, $g2) = create_ws_client(
        test_mojo => $t,
        nickname => 'GameB_Player',
        language => 'fr', # Different language = different game
    );
    
    ok($p1 && $p2, 'Both players connected');
    
    my $game1 = $g1->{gameId};
    my $game2 = $g2->{gameId};
    
    ok(defined $game1 && defined $game2, 'Both have game IDs');
    if (!($game1 && $game2)) {
        use Data::Dumper;
        diag("G1 Payload: " . Dumper($g1));
        diag("G2 Payload: " . Dumper($g2));
    }
    diag("Game 1: $game1, Game 2: $game2") if !($game1 && $game2);
    
    # Player 1 sends a chat in their game
    my $chat1 = encode_json({
        type => 'chat',
        payload => { text => 'Secret message in game A' }
    });
    
    $ws1->send_ok($chat1);
    
    # Player 1 should receive their own message
    my $echo = wait_for_message($ws1, 'chat', 10);
    if (!$echo) {
        use Data::Dumper;
        diag("Player 1 failed to get chat echo. Current wait_for_message state might be lossy.");
    }
    ok($echo, 'Player 1 got echo');
    is($echo ? $echo->{text} : undef, 'Secret message in game A', 'Echo correct');
    
    # Player 2 should NOT receive this message (different game)
    # Use wait_for_message with small timeout - it should fail to find 'chat'
    my $no_chat = wait_for_message($ws2, 'chat', 1);
    
    if (!$no_chat) {
        pass('Player 2 received no chat message from Player 1 (correct isolation)');
    } else {
        fail('Player 2 received unintended chat message');
        diag("Unexpected message: " . $no_chat->{text});
    }
    
    $ws1->finish_ok;
    $ws2->finish_ok;
    
    done_testing();
};

cleanup_test_games($t);

subtest 'Player disconnection handling' => sub {
    my ($ws1, $p1, $g1) = create_ws_client(
        test_mojo => $t,
        nickname => 'StayingPlayer',
    );
    
    my ($ws2, $p2, $g2) = create_ws_client(
        test_mojo => $t,
        nickname => 'LeavingPlayer',
    );
    
    ok($p1 && $p2, 'Both players connected');
    
    # No need to clear start messages anymore
    
    # Player 2 disconnects
    $ws2->finish_ok;
    
    # Player 1 should still be connected and functional
    my $chat = encode_json({
        type => 'chat',
        payload => { text => 'Anyone still here?' }
    });
    
    $ws1->send_ok($chat);
    
    # Should still receive own message
    my $msg = wait_for_message($ws1, 'chat', 10);
    ok($msg, 'Player 1 still functional after P2 disconnect');
    is($msg ? $msg->{text} : undef, 'Anyone still here?', 'Still receiving chat messages');
    
    $ws1->finish_ok;
    
    done_testing();
};

subtest 'Rapid connect-disconnect stress' => sub {
    # Rapidly create and destroy connections
    for my $i (1..5) {
        my ($ws, $pid, $payload) = create_ws_client(
            test_mojo => $t,
            nickname => "Rapid$i",
        );
        
        ok($pid, "Rapid connection $i successful");
        $ws->finish_ok;
    }
    
    done_testing();
};

cleanup_test_games($t);

done_testing();
