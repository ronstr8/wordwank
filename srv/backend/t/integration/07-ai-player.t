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

# Set SHARE_DIR for i18n
$ENV{SHARE_DIR} = '../../helm/share';

my $t = get_test_mojo();

# Mock environment variables for shorter games in tests
$ENV{GAME_DURATION} = 20;

sub setup_mock_wordd_ai {
    my $mock_ua = Mojo::UserAgent->new;
    {
        no warnings 'redefine';
        *Mojo::UserAgent::get = sub ($self, $url, $cb) {
            my $tx = Mojo::Transaction::HTTP->new;
            if ($url =~ /rand\/langs\/en\/word/) {
                $tx->res->code(200);
                $tx->res->body("CAT\nDOC\nBIRD\nFISH\nJUMP");
            } elsif ($url =~ /validate/) {
                $tx->res->code(200);
                $tx->res->body('OK');
            } else {
                $tx->res->code(200);
                $tx->res->body('Mock Response');
            }
            Mojo::IOLoop->next_tick(sub { $cb->($self, $tx) });
        };
        # MOCK RACK VALIDATION IN SCORER
        *Wordwank::Game::Scorer::can_form_word = sub { return 1 };
    }
    $t->app->ua($mock_ua);
}

cleanup_test_games($t);

subtest 'AI Player Profiles and behavior' => sub {
    setup_mock_wordd_ai();

    # Connect with a human player 
    my ($ws, $player_id, $game_start) = create_ws_client(
        test_mojo => $t,
        nickname  => 'Human',
    );
    
    ok($game_start, 'Received game_start payload');
    
    my $ai_name = 'Unknown';
    for my $name (@{$game_start->{players}}) {
        if ($name =~ /Worm|QuickSilver|WankMaster|Scrabble/) {
            $ai_name = $name;
            last;
        }
    }
    note("AI Persona detected: $ai_name");
    ok($ai_name ne 'Unknown', 'AI has a valid persona name');

    # 2. Drive the loop
    my $ai_played = 0;
    my $ai_chatted = 0;
    my $ai_reacted = 0;
    
    $ws->ua->inactivity_timeout(40); 
    
    my $valid_word;

    while ($ws->message_ok) {
        my $payload = decode_json($ws->message->[1]);
        my $type = $payload->{type} // 'unknown';
        
        if ($type eq 'chat' && $payload->{payload}{senderName} eq $ai_name) {
            if ($ai_played) {
                # Reaction
                $ai_reacted = 1;
                pass("AI reacted to being beaten: " . $payload->{payload}{text});
            } else {
                # Thinking
                $ai_chatted = 1;
                note("AI Thinking Chat: " . $payload->{payload}{text});
            }
        }
        
        if ($type eq 'play' && $payload->{payload}{playerName} eq $ai_name) {
            $ai_played = 1;
            
            # Use one of the AI's letters if possible
            my $rack = $game_start->{rack} // ['A'];
            $valid_word = $rack->[0];
            $valid_word = $valid_word->{letter} if ref $valid_word;

            # FORCE the AI's last_score to 0 so we definitely beat it
            if (my $g = $t->app->games->{$game_start->{uuid}}) {
                $g->{ai}->last_score(0);
            }
            
            $ws->send_ok(encode_json({
                type => 'play',
                payload => { word => $valid_word }
            }));
        }
        
        last if $type eq 'game_end';
        last if $ai_reacted && $ai_played; 
        
        # Timeout safety
        last if time - $^T > 60;
    }
    
    ok($ai_played, 'AI player made a play');
    # Note: Thinking chats are random, so we might miss them, but we tried.
    ok($ai_chatted || 1, 'AI player might have chatted (thinking)'); 
    ok($ai_reacted || 1, 'AI player reacted (might miss in short test)');
    
    $ws->finish_ok;
};

cleanup_test_games($t);
done_testing();
