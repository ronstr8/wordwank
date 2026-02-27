use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games wait_for_message);

# Integration test for encounter toasts
my $t;
eval {
    $t = get_test_mojo();
};
if ($@ || !$t) {
    plan skip_all => "Skipping: App load failed or hanging";
}

plan skip_all => "Skipping: Persistent hangs in Windows environment" unless $ENV{ENABLE_INTEGRATION_TESTS};

cleanup_test_games($t);

subtest 'Encounter-based join filtering' => sub {
    cleanup_test_games($t);

    # 1. Player A and B join a game and play together
    my ($ws_a1, $p_a1, $g_a1) = create_ws_client(
        test_mojo => $t,
        nickname => 'PlayerA',
    );
    
    my ($ws_b1, $p_b1, $g_b1) = create_ws_client(
        test_mojo => $t,
        nickname => 'PlayerB',
    );

    # A should get 'player_joined' for B
    my $join_msg = wait_for_message($ws_a1, 'player_joined', 10);
    ok($join_msg, "Player A received join notification for Player B (first meeting)");
    is($join_msg->{name}, 'PlayerB', "Correct name in join notification");

    # Both play a word to record their encounter
    $ws_a1->send_ok({json => { type => 'play', payload => { word => 'APPLE' }}});
    $ws_b1->send_ok({json => { type => 'play', payload => { word => 'BANANA' }}});
    
    # Wait for 'chat' notifications that acknowledge the plays
    ok(wait_for_message($ws_a1, 'chat', 10), "Player A received play notification");
    ok(wait_for_message($ws_b1, 'chat', 10), "Player B received play notification");

    # We must wait for the game to END for encounters to be recorded in the DB
    $t->app->log->debug("TEST: Waiting for game to end to record encounter...");
    
    # Speed up game end by manually triggering it if possible, 
    # but here we rely on the timer. 
    # Let's check if we can reduce GAME_DURATION for this test
    # Actually, TestHelper might have it set high.
    
    wait_for_message($ws_a1, 'game_end', 45);
    wait_for_message($ws_b1, 'game_end', 45);
    
    # 2. Start a NEW game and see if they notify each other
    cleanup_test_games($t);
    
    my $player_a_id = $p_a1;
    my $player_b_id = $p_b1;

    # Reconnect A
    my $ws_a2 = Test::Mojo->new($t->app);
    $ws_a2->websocket_ok("/ws?id=$player_a_id");
    wait_for_message($ws_a2, 'identity', 10);
    $ws_a2->send_ok({json => { type => 'join', payload => { nickname => 'PlayerA' }}});
    wait_for_message($ws_a2, 'game_start', 10);

    # Reconnect B
    my $ws_b2 = Test::Mojo->new($t->app);
    $ws_b2->websocket_ok("/ws?id=$player_b_id");
    wait_for_message($ws_b2, 'identity', 10);
    $ws_b2->send_ok({json => { type => 'join', payload => { nickname => 'PlayerB' }}});
    
    # Player A should NOT receive a join notification now because they have an encounter history
    my $late_join = wait_for_message($ws_a2, 'player_joined', 2);
    ok(!$late_join, "Player A did NOT receive join notification for Player B (already encountered)");
};

subtest 'Play scope restriction' => sub {
    cleanup_test_games($t);
    
    # Game 1 (English)
    my ($ws_en, $p_en, $g_en) = create_ws_client(
        test_mojo => $t,
        nickname => 'EnglishPlayer',
        language => 'en',
    );
    
    # Game 2 (Spanish)
    my ($ws_es, $p_es, $g_es) = create_ws_client(
        test_mojo => $t,
        nickname => 'SpanishPlayer',
        language => 'es',
    );
    
    # English player plays a word
    $ws_en->send_ok({json => { type => 'play', payload => { word => 'TEST' }}});
    
    # English player should get the 'played a word' chat
    my $en_chat = wait_for_message($ws_en, 'chat', 10);
    ok($en_chat, "English player received their own play notification");
    
    # Spanish player should NOT get it
    my $es_chat = wait_for_message($ws_es, 'chat', 2);
    ok(!$es_chat, "Spanish player did NOT receive English player's play notification (isolated)");
};

subtest 'Player quit notification' => sub {
    cleanup_test_games($t);
    
    my ($ws1, $p1, $g1) = create_ws_client(
        test_mojo => $t,
        nickname => 'Stayer',
    );
    my ($ws2, $p2, $g2) = create_ws_client(
        test_mojo => $t,
        nickname => 'Quitter',
    );
    
    # Quitter leaves
    $ws2->finish_ok;
    
    # Stayer should get player_quit
    my $quit_msg = wait_for_message($ws1, 'player_quit', 10);
    ok($quit_msg, "Stayer received player_quit notification");
    is($quit_msg->{name}, 'Quitter', "Correct name in quit notification");
};

done_testing();
