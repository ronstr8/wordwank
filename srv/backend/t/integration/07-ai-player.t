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
$ENV{GAME_DURATION} = 15;

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
        
        # ALSO MOCK RACK VALIDATION to ensure our test play always succeeds
        *Wordwank::Web::Game::_has_valid_tiles = sub { return 1 };
    }
    $t->app->ua($mock_ua);
}

cleanup_test_games($t);

subtest 'AI Player presence and behavior' => sub {
    setup_mock_wordd_ai();

    # Connect with a human player 
    my ($ws, $player_id, $game_start) = create_ws_client(
        test_mojo => $t,
        nickname  => 'Human',
    );
    
    ok($game_start, 'Received game_start payload');
    ok(scalar(@{$game_start->{players}}) >= 1, 'AI player should be in the game');
    
    my $ai_name = $game_start->{players}[0];
    note("AI Name detected: $ai_name");

    # 2. Drive the loop
    my $ai_played = 0;
    my $ai_chatted = 0;
    my $ai_reacted = 0;
    
    $ws->ua->inactivity_timeout(20); 
    
    # Use any word since validation is mocked
    my $valid_word = 'TEST';
    note("Human will play: $valid_word");

    while ($ws->message_ok) {
        my $payload = decode_json($ws->message->[1]);
        my $type = $payload->{type} // 'unknown';
        
        if ($type eq 'chat' && $payload->{payload}{senderName} eq $ai_name) {
            if ($ai_played) {
                if ($payload->{payload}{text} !~ /ai\.reaction_beaten/) {
                    $ai_reacted = 1;
                    pass("AI reacted to being beaten: " . $payload->{payload}{text});
                }
            } else {
                if ($payload->{payload}{text} !~ /ai\.thinking/) {
                    $ai_chatted = 1;
                    note("AI Thinking Chat: " . $payload->{payload}{text});
                }
            }
        }
        
        if ($type eq 'play' && $payload->{payload}{playerName} eq $ai_name) {
            $ai_played = 1;
            
            # FORCE the AI's last_score to 0 so we definitely beat it
            if (my $g = $t->app->games->{$game_start->{uuid}}) {
                $g->{ai}->last_score(0);
            }
            
            note("Human (us) playing '$valid_word' to trigger reaction");
            $ws->send_ok(encode_json({
                type => 'play',
                payload => { word => $valid_word }
            }));
        }
        
        last if $type eq 'game_end';
        last if $ai_reacted && $ai_played; # Success
    }
    
    ok($ai_played, 'AI player made a play');
    ok($ai_chatted, 'AI player chatted (thinking)');
    ok($ai_reacted, 'AI player reacted (beaten)');
    
    $ws->finish_ok;
};

cleanup_test_games($t);
done_testing();
