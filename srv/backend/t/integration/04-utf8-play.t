use v5.36;
use utf8;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::Transaction::HTTP;
use Mojo::IOLoop;
use UUID::Tiny qw(:std);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client cleanup_test_games);

# Ensure we use raw UTF-8 for output
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $t = get_test_mojo();

# Manual mock for Mojo::UserAgent that simulates wordd validation
# and injects it into the test app instance.
sub setup_mock_wordd ($code, $expected_word_match = undef) {
    my $mock_ua = Mojo::UserAgent->new;
    {
        no warnings 'redefine';
        *Mojo::UserAgent::get = sub ($self, $url, $cb) {
            my $tx = Mojo::Transaction::HTTP->new;
            if ($expected_word_match && $url =~ /$expected_word_match/) {
                $tx->res->code(200);
                $tx->res->body('OK');
            } else {
                $tx->res->code($code);
                $tx->res->body($code == 404 ? 'Not Found' : 'Error');
            }
            Mojo::IOLoop->next_tick(sub { $cb->($self, $tx) });
        };
    }
    $t->app->ua($mock_ua);
}

cleanup_test_games($t);

subtest 'Unicode word submission validates and broadcasts' => sub {
    setup_mock_wordd(200, '%c3%b1ame'); # Match encoded ÑAME

    # Manually create a game with Ñ in the rack
    my $gid = UUID::Tiny::create_uuid_as_string(UUID_V4);
    $t->app->schema->resultset('Game')->create({
        id            => $gid,
        rack          => '{Ñ,A,M,E,X,Y,Z}', # Postgres format for inflation
        letter_values => Mojo::JSON::encode_json({ 'Ñ' => 5, 'A' => 1, 'M' => 3, 'E' => 1, 'X' => 8, 'Y' => 4, 'Z' => 10 }),
        language      => 'es',
        started_at    => DateTime->now,
    });

    # Connect with a player
    my ($ws, $player_id) = create_ws_client(
        test_mojo => $t,
        nickname  => 'Ñamador',
        language  => 'es',
    );
    
    # Submit Unicode word
    $ws->send_ok(encode_json({
        type => 'play',
        payload => { word => 'ÑAME' }
    }));
    
    # Wait for 'play' broadcast
    $ws->success_timeout(2);
    my $found = 0;
    while ($ws->message_ok) {
        my $payload = decode_json($ws->message->[1]);
        if ($payload->{type} eq 'play') {
            is($payload->{payload}{word}, 'ÑAME', 'Correct Unicode word echoed');
            $found = 1;
            last;
        }
    }
    $ws->success_timeout(10);
    ok($found, 'Received play broadcast for Unicode word');
    
    $ws->finish_ok;
};

subtest 'Server error handling (500) returns custom message' => sub {
    setup_mock_wordd(500);

    my ($ws, $player_id) = create_ws_client(
        test_mojo => $t,
        nickname  => 'ErrorTester',
    );
    
    $ws->send_ok(encode_json({
        type => 'play',
        payload => { word => 'FOO' }
    }));
    
    # Wait for 'error' message
    $ws->success_timeout(2);
    my $found = 0;
    while ($ws->message_ok) {
        my $payload = decode_json($ws->message->[1]);
        if ($payload->{type} eq 'error') {
            is($payload->{payload}, 'Fecking server error!', 'Correct custom error message received');
            $found = 1;
            last;
        }
    }
    $ws->success_timeout(10);
    ok($found, 'Received custom error message on wordd 500');
    
    $ws->finish_ok;
};

cleanup_test_games($t);
done_testing();
