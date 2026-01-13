package Wordwank;
use Mojo::Base 'Mojolicious', -signatures;
use Wordwank::Schema;
use Wordwank::Game::Scorer;
use UUID::Tiny qw(:std);

has schema => sub {
    my $self = shift;
    my $dsn = $ENV{DATABASE_URL} || 'dbi:Pg:dbname=wordwank;host=postgres';
    return Wordwank::Schema->connect($dsn, $ENV{DB_USER}, $ENV{DB_PASS}, {
        pg_enable_utf8 => 1,
        quote_names    => 1,
    });
};

has scorer => sub { Wordwank::Game::Scorer->new };

# Track connected clients by Game UUID
has games => sub { {} };

has ua => sub { Mojo::UserAgent->new };

sub startup ($self) {
    # Plugins
    $self->plugin('NotYAMLConfig' => {file => 'wordwank.yml', optional => 1});
    
    # Session Secrets
    $self->secrets([$ENV{SESSION_SECRET} || 'wordwank-dev-secret-keep-it-safe']);

    # Helpers
    $self->helper(schema => sub ($c) { $c->app->schema });

    # Simple i18n dictionary for backend summaries
    my $translations = {
        en => {
            'results.winner_summary' => "%s won with %d points (Word: %s)",
            'results.no_winner'      => "No one played a word this round. Wankers.",
            'results.solo_wanker'    => "Unfortunately, a lonely wanker gets no points.",
        },
        es => {
            'results.winner_summary' => "%s ganó con %d puntos (Palabra: %s)",
            'results.no_winner'      => "Nadie jugó una palabra. Pajilleros.",
            'results.solo_wanker'    => "Lamentablemente, un pajillero solitario no recibe puntos.",
        },
        fr => {
            'results.winner_summary' => "%s a gagné avec %d points (Mot: %s)",
            'results.no_winner'      => "Personne n'a joué de mot. Branleurs.",
            'results.solo_wanker'    => "Malheureusement, un branleur solitaire ne reçoit aucun point.",
        },
    };

    $self->helper(t => sub ($c, $key, $lang = undef) {
        $lang ||= 'en';
        return $translations->{$lang}{$key} || $translations->{en}{$key} || $key;
    });

    # OAuth2 Configuration (Google)
    $self->plugin('OAuth2' => {
        google => {
            key    => $ENV{GOOGLE_CLIENT_ID} || 'MISSING',
            secret => $ENV{GOOGLE_CLIENT_SECRET} || 'MISSING',
        }
    });

    # Verify plugin is loaded (for debugging)
    if (!$self->renderer->get_helper('oauth2')) {
        $self->app->log->error("OAuth2 helper MISSING after plugin load!");
    }

    # Routes
    my $r = $self->routes;
    $r->namespaces(['Wordwank::Web']);

    # Auth Routes
    my $auth = $r->any('/auth');
    $auth->get('/google')->to('auth#google_login');
    $auth->get('/google/callback')->to('auth#google_callback')->name('google_callback');
    $auth->get('/me')->to('auth#me');
    $auth->post('/logout')->to('auth#logout');
    $auth->get('/passkey/challenge')->to('auth#passkey_challenge');
    $auth->post('/passkey/verify')->to('auth#passkey_verify');

    # WebSocket for game
    $r->websocket('/ws')->to('game#websocket');

    # HTTP API for stats
    $r->get('/players/leaderboard')->to('stats#leaderboard');

    # Background task: Pre-populate games (ensure every language has a pending or active game)
    $self->helper(prepopulate_games => sub ($c) {
        my $schema = $c->app->schema;
        my @langs = qw(en es fr);
        
        for my $lang (@langs) {
            # Check if there is an active (started) or pending (created but not started) game
            my $game = $schema->resultset('Game')->search({
                finished_at => undef,
                language    => $lang,
            }, { rows => 1 })->single;

            if (!$game) {
                $c->app->log->debug("Pre-populating pending game for $lang");
                my $rack = $c->app->scorer->get_random_rack($lang);
                my $vals = $c->app->scorer->generate_letter_values($lang);
                
                eval {
                    $schema->resultset('Game')->create({
                        id            => create_uuid_as_string(UUID_V4),
                        rack          => $rack,
                        letter_values => $vals,
                        language      => $lang,
                        started_at    => undef, # Pending
                    });
                    1; # Return true on success
                } or do {
                    $c->app->log->warn("Failed to create game for $lang: $@");
                };
            }
        }
    });

    # Run every 10 seconds
    Mojo::IOLoop->recurring(10 => sub {
        my $loop = shift;
        # Re-seed srand to ensure preforked workers don't share identical PRNG state.
        # Avoid 'ps' as it's often missing in minimal containers.
        if (open my $fh, '<:raw', '/dev/urandom') {
            read $fh, my $buf, 4;
            srand(unpack('L', $buf) ^ $$ ^ time);
            close $fh;
        } else {
            srand(time ^ $$ ^ int(rand(1000000)));
        }
        
        $self->prepopulate_games();
    });
}

1;
