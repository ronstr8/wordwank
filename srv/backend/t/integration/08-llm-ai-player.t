use v5.36;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

package main;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use Mojo::Transaction::HTTP;
use Mojo::IOLoop;
use UUID::Tiny qw(:std);
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo cleanup_test_games);

# Mock environment
$ENV{OLLAMA_URL} = 'http://mock-ollama:11434';
$ENV{OLLAMA_MODEL} = 'phi3:mini';
$ENV{GAME_DURATION} = 15;

my $t = get_test_mojo();

sub setup_mock_ollama {
    my $mock_ua = Mojo::UserAgent->new;
    {
        no warnings 'redefine';
        *Mojo::UserAgent::post = sub ($self, $url, %args) {
            my $tx = Mojo::Transaction::HTTP->new;
            if ($url =~ /api\/generate/) {
                my $prompt = $args{json}{prompt} // '';
                
                # VERIFICATION: Check if prompt contains rules and rack
                # "Rules:" is in the preamble
                # "Your Current Tiles" is in the preamble
                if ($prompt =~ /Game Rules:/ && $prompt =~ /Your Current Tiles/) {
                    pass("Ollama prompt contains game context preamble");
                } else {
                    fail("Ollama prompt MISSING game context preamble");
                    diag("Prompt was: $prompt");
                }

                my $response = "I am a helpful character.";
                if ($prompt =~ /Yertyl/) {
                    $response = "Slow down, young wanker. I'm thinking.";
                }
                
                $tx->res->code(200);
                $tx->res->body(encode_json({ response => $response }));
            }
            # Attach callback if present
            my $cb = pop @_;
            if (ref $cb eq 'CODE') {
                Mojo::IOLoop->next_tick(sub { $cb->($self, $tx) });
            }
            return $tx;
        };
        
        # Wordd mock
        *Mojo::UserAgent::get = sub ($self, $url, $cb) {
             my $tx = Mojo::Transaction::HTTP->new;
             if ($url =~ /rand\/langs/) {
                 $tx->res->code(200);
                 $tx->res->body("TEST\nWORD");
             }
             Mojo::IOLoop->next_tick(sub { $cb->($self, $tx) });
        };
    }
    $t->app->ua($mock_ua);
}

cleanup_test_games($t);

subtest 'LLM AI Character Dialogue with Context' => sub {
    setup_mock_ollama();

    # Manual WebSocket setup
    my $tm = Test::Mojo->new($t->app);
    $tm->websocket_ok('/ws?lang=en')
       ->status_is(101);

    my $ws_tx = $tm->tx;
    my @messages;
    $ws_tx->on(message => sub ($tx, $msg) {
        my $data = eval { decode_json($msg) };
        push @messages, $data if $data;
    });

    # 1. Join immediately to trigger backend work
    $tm->send_ok({json => {
        type => 'join',
        payload => { nickname => 'Human', language => 'en' }
    }});

    # 2. Capture messages
    my $ai_name;
    my $ai_spoke = 0;
    my $start = time;
    note("Monitoring game flow...");
    
    while (time - $start < 30) {
        $tm->ua->ioloop->one_tick;
        
        # Identify AI
        if (!$ai_name) {
            if (my ($gs) = grep { $_->{type} eq 'game_start' } @messages) {
                $ai_name = $gs->{payload}{players}->[-1];
                note("AI Persona detected: $ai_name");
            }
        }
        
        # Check for AI Chat
        if ($ai_name) {
            if (my ($chat) = grep { $_->{type} eq 'chat' && ($_->{payload}{senderName} eq $ai_name || $_->{payload}{senderName} =~ /WankBot/) } @messages) {
                $ai_spoke = 1;
                my $text = $chat->{payload}{text};
                note("AI said: $text");
                pass("AI character generated dialogue: $text");
                last;
            }
        }
        
        select(undef, undef, undef, 0.1) unless @messages;
    }
    
    ok($ai_spoke, 'AI character generated dialogue via Ollama');
    $tm->finish_ok;
};

cleanup_test_games($t);
done_testing();
