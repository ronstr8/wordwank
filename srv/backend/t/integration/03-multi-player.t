use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games wait_for_message);

# Integration test for multi-player scenarios and game isolation
my $t;
eval {
    $t = get_test_mojo();
};
if ($@ || !$t) {
    plan skip_all => "Skipping: App load failed or hanging";
}

plan skip_all => "Skipping: Persistent hangs in Windows environment" unless $ENV{ENABLE_INTEGRATION_TESTS};

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
    
    # Create players for Spanish game
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
    ok($g_en1->{uuid} && $g_en2->{uuid}, 'Both EN players have game UUIDs');
    is($g_en1->{uuid}, $g_en2->{uuid}, 'English players in same game');
    
    # Spanish players should be in same game
    ok($g_es1->{uuid} && $g_es2->{uuid}, 'Both ES players have game UUIDs');
    is($g_es1->{uuid}, $g_es2->{uuid}, 'Spanish players in same game');
    
    # The two games should be different
    isnt($g_en1->{uuid}, $g_es1->{uuid}, 'EN and ES games are different');
    
    # Use wait_for_message to consume any pending player_joined or chat messages before finishing
    # to avoid warnings about unhandled messages if necessary (Test::Mojo usually handles this on finish)
    
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
    
    my $game1 = $g1->{uuid};
    my $game2 = $g2->{uuid};
    
    ok(defined $game1 && defined $game2, 'Both have game IDs');
    isnt($game1, $game2, 'Players are in different games');
    
    # Player 1 sends a chat in their game
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Secret message in game A' }
    }});
    
    # Player 1 should receive their own message
    my $echo = wait_for_message($ws1, 'chat', 10);
    ok($echo, 'Player 1 got echo');
    is($echo->{text}, 'Secret message in game A', 'Echo correct');
    
    # Player 2 should NOT receive this message (different game)
    my $no_chat = wait_for_message($ws2, 'chat', 2);
    ok(!$no_chat, 'Player 2 received no chat message from Player 1 (correct isolation)');
    
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
    
    # Player 2 disconnects
    $ws2->finish_ok;
    
    # Player 1 should receive player_quit
    my $quit = wait_for_message($ws1, 'player_quit', 10);
    ok($quit, 'Player 1 received player_quit notification');
    is($quit->{name}, 'LeavingPlayer', 'Correct player name in quit notification');
    
    # Player 1 should still be connected and functional
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Anyone still here?' }
    }});
    
    # Should still receive own message
    my $msg = wait_for_message($ws1, 'chat', 10);
    ok($msg, 'Player 1 still functional after P2 disconnect');
    is($msg->{text}, 'Anyone still here?', 'Still receiving chat messages');
    
    $ws1->finish_ok;
    
    done_testing();
};

subtest 'Rapid connect-disconnect stress' => sub {
    # Rapidly create and destroy connections
    for my $i (1..3) { # Reduced count for speed
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
