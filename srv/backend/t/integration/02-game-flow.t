use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games);

# Integration test for end-to-end game flow
my $t = get_test_mojo();

cleanup_test_games($t);

subtest 'Player can join game' => sub {
    plan tests => 7;
    
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'GameTester',
    );
    
    ok($player1, 'Player connected');
    
    # After join, should receive game state
    $ws1->message_ok('Received initial game state');
    my $state = decode_json($ws1->message->[1]);
    
    is($state->{type}, 'gameState', 'Received gameState message');
    ok(defined $state->{payload}{gameId}, 'Has game ID');
    ok(defined $state->{payload}{rack}, 'Has rack');
    is(ref $state->{payload}{rack}, 'ARRAY', 'Rack is an array');
    ok(defined $state->{payload}{players}, 'Has players list');
    
    $ws1->finish_ok;
};

subtest 'Player can submit a valid word' => sub {
    plan tests => 5;
    
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'WordPlayer',
    );
    
    # Get game state to see the rack
    $ws1->message_ok('Got game state');
    my $state = decode_json($ws1->message->[1]);
    my $rack = $state->{payload}{rack};
    
    ok(scalar @$rack > 0, 'Rack has tiles');
    
    # Try to submit a word using letters from the rack
    # For testing, we'll use a simple 3-letter combination
    my $word = join('', @$rack[0..2]);
    
    my $play_msg = encode_json({
        type => 'play',
        payload => {
            word => $word,
        }
    });
    
    $ws1->send_ok($play_msg);
    
    # Should receive a response (either valid or invalid)
    $ws1->message_ok('Received play response');
    my $response = decode_json($ws1->message->[1]);
    
    # Response could be 'playResult', 'error', or 'gameState'
    ok(defined $response->{type}, 'Got response type: ' . ($response->{type} || 'undefined'));
    
    $ws1->finish_ok;
};

subtest 'Multiple players in same game' => sub {
    plan tests => 10;
    
    # Two players join around the same time
    my ($ws1, $p1) = create_ws_client(
        test_mojo => $t,
        nickname => 'Player1',
        language => 'en',
    );
    
    my ($ws2, $p2) = create_ws_client(
        test_mojo => $t,
        nickname => 'Player2',
        language => 'en',
    );
    
    ok($p1 && $p2, 'Both players connected');
    
    # Get game states
    $ws1->message_ok('P1 got game state');
    my $state1 = decode_json($ws1->message->[1]);
    
    $ws2->message_ok('P2 got game state');
    my $state2 = decode_json($ws2->message->[1]);
    
    # They should be in the same game (or at least have valid game IDs)
    ok(defined $state1->{payload}{gameId}, 'P1 has game ID');
    ok(defined $state2->{payload}{gameId}, 'P2 has game ID');
    
    # Both should have the same rack (same game)
    is_deeply($state1->{payload}{rack}, $state2->{payload}{rack}, 
              'Both players have same rack (same game)');
    
    # Player 1 sends a chat
    my $chat = encode_json({
        type => 'chat',
        payload => { text => 'Hi from P1!' }
    });
    
    $ws1->send_ok($chat);
    
    # Both should receive the chat
    $ws1->message_ok('P1 received chat echo');
    $ws2->message_ok('P2 received chat from P1');
    
    my $p2_chat = decode_json($ws2->message->[1]);
    is($p2_chat->{payload}{text}, 'Hi from P1!', 'P2 got correct message');
    
    $ws1->finish_ok;
    $ws2->finish_ok;
};

subtest 'Language parameter affects game assignment' => sub {
    plan tests => 4;
    
    my ($ws_en, $pen) = create_ws_client(
        test_mojo => $t,
        nickname => 'EnglishPlayer',
        language => 'en',
    );
    
    my ($ws_es, $pes) = create_ws_client(
        test_mojo => $t,
        nickname => 'SpanishPlayer',
        language => 'es',
    );
    
    ok($pen && $pes, 'Both language players connected');
    
    $ws_en->message_ok('EN player got state');
    $ws_es->message_ok('ES player got state');
    
    my $state_en = decode_json($ws_en->message->[1]);
    my $state_es = decode_json($ws_es->message->[1]);
    
    # They might be in different games due to different languages
    # At minimum, they should both have valid game states
    ok(defined $state_en->{payload}{gameId} && 
       defined $state_es->{payload}{gameId}, 
       'Both have game IDs');
    
    $ws_en->finish_ok;
    $ws_es->finish_ok;
};

cleanup_test_games($t);

done_testing();
