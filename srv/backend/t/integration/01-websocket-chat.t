use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::JSON qw(encode_json decode_json);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client wait_for_message cleanup_test_games);

# Integration test for WebSocket chat functionality
my $t;
eval {
    $t = get_test_mojo();
};
if ($@ || !$t) {
    plan skip_all => "Skipping: App load failed or hanging";
}

plan skip_all => "Skipping: Persistent hangs in Windows environment" unless $ENV{ENABLE_INTEGRATION_TESTS};

cleanup_test_games($t);

subtest 'Single player can connect and chat' => sub {
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'ChatTester1',
    );
    
    ok($player1, 'Player 1 connected and received player ID');
    like($player1, qr/^[0-9a-f-]{36}$/i, 'Player ID looks like a UUID');
    
    # Send a chat message
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Hello from test!' }
    }});
    
    # Should receive our own chat message back (broadcast)
    my $response = wait_for_message($ws1, 'chat', 10);
    ok($response, 'Received chat broadcast');
    
    is($response->{text}, 'Hello from test!', 'Chat text matches');
    
    $ws1->finish_ok;
    done_testing();
};

subtest 'Multiple players can chat' => sub {
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
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Hi Bob!' }
    }});
    
    # Alice should receive her own message
    my $alice_echo = wait_for_message($ws1, 'chat', 10);
    ok($alice_echo, 'Alice received broadcast');
    is($alice_echo->{senderName}, 'Alice', 'Sender name is Alice');
    
    # Bob should also receive Alice's message
    my $bob_received = wait_for_message($ws2, 'chat', 10);
    ok($bob_received, 'Bob received Alice\'s message');
    is($bob_received->{text}, 'Hi Bob!', 'Bob got correct message text');
    
    $ws1->finish_ok;
    $ws2->finish_ok;
    done_testing();
};

subtest 'Chat message format validation' => sub {
    my ($ws1, $player1) = create_ws_client(
        test_mojo => $t,
        nickname => 'FormatTester',
    );
    
    # Send a chat with special characters
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Testing émojis 🎮 and spëcial chars!' }
    }});
    
    my $response = wait_for_message($ws1, 'chat', 10);
    ok($response, 'Received special char message');
    
    # In the broadcast, the sender ID is outside the payload
    # wait_for_message returns the payload
    ok($response->{text} =~ /émojis/, 'UTF-8 characters preserved');
    
    # We can check senderName which IS in the payload
    is($response->{senderName}, 'FormatTester', 'Has correct sender name');
    
    $ws1->finish_ok;
    done_testing();
};

subtest 'Three-way chat broadcast' => sub {
    my ($ws1, $p1) = create_ws_client(test_mojo => $t, nickname => 'Player1');
    my ($ws2, $p2) = create_ws_client(test_mojo => $t, nickname => 'Player2');
    my ($ws3, $p3) = create_ws_client(test_mojo => $t, nickname => 'Player3');
    
    ok($p1 && $p2 && $p3, 'All three players connected');
    
    # Player 1 sends a message
    $ws1->send_ok({json => {
        type => 'chat',
        payload => { text => 'Hello everyone!' }
    }});
    
    # All three should receive it
    my $r1 = wait_for_message($ws1, 'chat', 10);
    my $r2 = wait_for_message($ws2, 'chat', 10);
    my $r3 = wait_for_message($ws3, 'chat', 10);
    
    ok($r1, 'Player 1 received own message');
    ok($r2, 'Player 2 received message');
    ok($r3, 'Player 3 received message');
    
    # Verify content on player 2
    is($r2->{text}, 'Hello everyone!', 'Player 2 got correct text');
    is($r2->{senderName}, 'Player1', 'Player 2 sees correct sender');
    
    $ws1->finish_ok;
    $ws2->finish_ok;
    $ws3->finish_ok;
    done_testing();
};

# Cleanup after tests
cleanup_test_games($t);

done_testing();
