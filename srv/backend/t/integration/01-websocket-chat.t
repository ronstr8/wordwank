use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client wait_for_message cleanup_test_games);

# Integration test for WebSocket chat functionality
my $t = get_test_mojo();

# Cleanup before tests
cleanup_test_games($t);

subtest 'Single player can connect and chat' => sub {
    plan tests => 5;
    
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'ChatTester1',
    );
    
    ok($player1, 'Player 1 connected and received player ID');
    like($player1, qr/^[0-9a-f-]{36}$/i, 'Player ID looks like a UUID');
    
    # Send a chat message
    my $chat_msg = encode_json({
        type => 'chat',
        payload => {
            text => 'Hello from test!',
        }
    });
    
    $ws1->send_ok($chat_msg);
    
    # Should receive our own chat message back (broadcast)
    $ws1->message_ok('Received chat broadcast');
    
    my $response = decode_json($ws1->message->[1]);
    is($response->{type}, 'chat', 'Message type is chat');
    is($response->{payload}{text}, 'Hello from test!', 'Chat text matches');
    
    $ws1->finish_ok;
};

subtest 'Multiple players can chat' => sub {
    plan tests => 8;
    
    # Create two WebSocket clients
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'Alice',
    );
    
    my ($ws2, $player2) = create_ws_client(
        test_mojo => $t,
        nickname => 'Bob',
    );
    
    ok($player1, 'Alice connected');
    ok($player2, 'Bob connected');
    isnt($player1, $player2, 'Players have different IDs');
    
    # Alice sends a message
    my $alice_msg = encode_json({
        type => 'chat',
        payload => { text => 'Hi Bob!' }
    });
    
    $ws1->send_ok($alice_msg);
    
    # Alice should receive her own message
    $ws1->message_ok('Alice received broadcast');
    my $alice_echo = decode_json($ws1->message->[1]);
    is($alice_echo->{type}, 'chat', 'Alice got chat type');
    is($alice_echo->{payload}{senderName}, 'Alice', 'Sender name is Alice');
    
    # Bob should also receive Alice's message
    $ws2->message_ok('Bob received Alice\'s message');
    my $bob_received = decode_json($ws2->message->[1]);
    is($bob_received->{payload}{text}, 'Hi Bob!', 'Bob got correct message text');
    
    $ws1->finish_ok;
    $ws2->finish_ok;
};

subtest 'Chat message format validation' => sub {
    plan tests => 5;
    
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'FormatTester',
    );
    
    # Send a chat with special characters
    my $special_msg = encode_json({
        type => 'chat',
        payload => { text => 'Testing émojis 🎮 and spëcial chars!' }
    });
    
    $ws1->send_ok($special_msg);
    $ws1->message_ok('Received special char message');
    
    my $response = decode_json($ws1->message->[1]);
    is($response->{type}, 'chat', 'Type is chat');
    ok(defined $response->{sender}, 'Has sender field');
    ok($response->{payload}{text} =~ /émojis/, 'UTF-8 characters preserved');
    
    $ws1->finish_ok;
};

subtest 'Three-way chat broadcast' => sub {
    plan tests => 9;
    
    my ($ws1, $p1) = create_ws_client(test_mojo => $t, nickname => 'Player1');
    my ($ws2, $p2) = create_ws_client(test_mojo => $t, nickname => 'Player2');
    my ($ws3, $p3) = create_ws_client(test_mojo => $t, nickname => 'Player3');
    
    ok($p1 && $p2 && $p3, 'All three players connected');
    
    # Player 1 sends a message
    my $msg = encode_json({
        type => 'chat',
        payload => { text => 'Hello everyone!' }
    });
    
    $ws1->send_ok($msg);
    
    # All three should receive it
    $ws1->message_ok('Player 1 received own message');
    $ws2->message_ok('Player 2 received message');
    $ws3->message_ok('Player 3 received message');
    
    # Verify content on player 2
    my $p2_msg = decode_json($ws2->message->[1]);
    is($p2_msg->{type}, 'chat', 'Player 2 got chat type');
    is($p2_msg->{payload}{text}, 'Hello everyone!', 'Player 2 got correct text');
    is($p2_msg->{payload}{senderName}, 'Player1', 'Player 2 sees correct sender');
    
    $ws1->finish_ok;
    $ws2->finish_ok;
    $ws3->finish_ok;
};

# Cleanup after tests
cleanup_test_games($t);

done_testing();
