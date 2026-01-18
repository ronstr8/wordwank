package Wordwank;
use Mojo::Base 'Mojolicious', -signatures;
use Wordwank::Schema;
use Wordwank::Game::Scorer;
use Wordwank::Game::Broadcaster;
use Mojo::JSON qw(decode_json);
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

    # Re-seed PRNG helper
    $self->helper(reseed_prng => sub ($c) {
        if (open my $fh, '<:raw', '/dev/urandom') {
            read $fh, my $buf, 4;
            srand(unpack('L', $buf) ^ $$ ^ time);
            close $fh;
        } else {
            srand(time ^ $$ ^ int(rand(1000000)));
        }
    });

    # Initial seed
    $self->reseed_prng();

    # Shared i18n: Load JSON locales from SHARE_DIR/locale
    my $share_base = $ENV{SHARE_DIR} || $self->home->child('share');
    my $share_dir  = Mojo::File->new($share_base)->child('locale');
    my $translations = {};

    $self->helper(load_translations => sub ($c) {
        if (-d $share_dir) {
            my $new_translations = {};
            for my $file (glob("$share_dir/*.json")) {
                my ($lang) = $file =~ /([^\\\/]+)\.json$/;
                eval {
                    my $content = Mojo::File->new($file)->slurp;
                    $new_translations->{$lang} = decode_json($content);
                };
                $c->app->log->error("Failed to load translation $file: $@") if $@;
            }
            $translations = $new_translations;
            $c->app->log->debug("Translations reloaded from $share_dir");
        }
    });

    # Initial load
    $self->load_translations();

    # Periodic check for hot-updates (every 5 minutes)
    Mojo::IOLoop->recurring(300 => sub { $self->load_translations() });

    $self->helper(t => sub ($c, $key, $lang = undef, $args = {}) {
        $lang ||= 'en';
        
        # Traverse nested keys (e.g., 'app.error_word_not_found')
        my $val = $translations->{$lang} // $translations->{en} // {};
        for my $part (split /\./, $key) {
            $val = $val->{$part} if ref $val eq 'HASH';
        }
        $val = $key unless defined $val && !ref $val;

        # i18next-style interpolation: {{variable}}
        $val =~ s/\{\{(.*?)\}\}/$args->{$1} \/\/ "{missing:$1}"/ge;
        return $val;
    });

    # OAuth2 Configuration (Google)
    $self->plugin('OAuth2' => {
        google => {
            key    => $ENV{GOOGLE_CLIENT_ID}     || 'MISSING',
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
    $auth->post('/anonymous')->to('auth#anonymous_login');
    $auth->get('/passkey/challenge')->to('auth#passkey_challenge');
    $auth->post('/passkey/verify')->to('auth#passkey_verify');

    # WebSocket for game
    $r->websocket('/ws')->to('game#websocket');

    # HTTP API for stats
    $r->get('/players/leaderboard')->to('stats#leaderboard');

    # Global Broadcast Helper (broadcasts to EVERY connected client in EVERY game)
    $self->helper(broadcast_all_clients => sub ($c, $msg) {
        $c->app->broadcaster->announce_all_but($msg);
    });

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
                
                # Attempt to create, ignore if someone else beat us to it (duplicate ID or same criteria)
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
                    my $err = $@ || 'unknown error';
                    if ($err =~ /unique constraint/i) {
                        $c->app->log->debug("Game already exists for $lang, skipping pre-population");
                    } else {
                        $c->app->log->warn("Failed to create game for $lang: $err");
                    }
                };
            }
        }
    });

    # Run every 10 seconds
    Mojo::IOLoop->recurring(10 => sub {
        my $loop = shift;
        # Re-seed to prevent identical UUIDs in preforked workers
        $self->reseed_prng();
        $self->prepopulate_games();
    });
}

1;
