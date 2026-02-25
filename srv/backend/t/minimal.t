use v5.36;
use utf8;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::Transaction::HTTP;

# Set up test database connection string
$ENV{DATABASE_URL} = 'dbi:SQLite:dbname=:memory:';

use lib 'lib';
require Wordwank;
my $t = Test::Mojo->new('Wordwank');
$t->app->schema->deploy;

# Mock ua
my $mock_ua = Mojo::UserAgent->new;
{
    no warnings 'redefine';
    *Mojo::UserAgent::get = sub {
        my ($self, $url, $cb) = @_;
        my $tx = Mojo::Transaction::HTTP->new;
        if ($url =~ /validate\/es\/%c3%b1ame/i) {
            $tx->res->code(200);
            $tx->res->body('OK');
        } else {
            $tx->res->code(500);
            $tx->res->body('Error');
        }
        $cb->($self, $tx);
    };
}
$t->app->ua($mock_ua);

subtest 'Minimal ASCII Test' => sub {
    # Set log level to debug
    $t->app->log->level('debug');

    # Create game
    my $gid = 'test-game-ascii';
    $t->app->schema->resultset('Game')->create({
        id => $gid,
        rack => '{N,A,M,E,X,Y,Z}',
        letter_values => encode_json({'N'=>1,'A'=>1,'M'=>3,'E'=>1,'X'=>8,'Y'=>4,'Z'=>10}),
        language => 'es',
        started_at => '2025-01-01 12:00:00',
    });

    # WebSocket connection
    $t->websocket_ok('/ws?id=testplayer')
      ->status_is(101);
    
    # Send play
    $t->send_ok(encode_json({ type => 'play', payload => { word => 'NAME' } }));
    
    # Wait for response
    my $found = 0;
    for (1..20) {
        $t->message_ok or last;
        my $raw = $t->message->[1];
        diag "RAW MESSAGE: $raw";
        my $msg = eval { decode_json($raw) };
        next unless $msg;
        if ($msg->{type} eq 'play') {
            is($msg->{payload}{word}, 'NAME', 'Correct word echoed');
            $found = 1;
            last;
        } elsif ($msg->{type} eq 'error') {
            diag "GOT ERROR: $msg->{payload}";
            # Don't last, might be identity first
        }
    }
    
    unless ($found) {
        diag "App logs:\n" . join "\n", map { $_->[1] . ': ' . $_->[2] } @{$t->app->log->history};
    }
    ok($found, 'Found play message');
};

done_testing();
