package Wordwank;
use Mojo::Base 'Mojolicious', -signatures;
use Wordwank::Schema;
use Wordwank::Game::Scorer;
use Wordwank::Game::Broadcaster;
use Mojo::JSON qw(decode_json);
use UUID::Tiny qw(:std);

has schema => sub {
    my $self = shift;
    my $dsn = $ENV{DATABASE_URL} || 'dbi:Pg:dbname=wordwank;host=postgresql';

    # Defensive logging (clean DSN for logs)
    my $log_dsn = $dsn;
    $log_dsn =~ s/:password=[^;]+/:password=****/i;
    $self->log->debug("Connecting to database: $log_dsn (user: " . ($ENV{DB_USER} // 'none') . ")");

    my $schema;
    eval {
        $schema = Wordwank::Schema->connect($dsn, $ENV{DB_USER}, $ENV{DB_PASS}, {
            pg_enable_utf8 => 1,
            quote_names    => 1,
            RaiseError     => 1,
        });
        # Test connection
        $schema->storage->dbh;
        $self->log->info("Database connected successfully.");
    };
    if ($@) {
        $self->log->error("DATABASE CONNECTION FAILED: $@");
        # We don't die here because we want the app to start and show errors in logs
    }

    return $schema;
};


has scorer => sub { Wordwank::Game::Scorer->new };

has broadcaster => sub ($self) { Wordwank::Game::Broadcaster->new(app => $self) };

# Track connected clients by Game UUID
has games => sub { {} };

# Store last X chat messages globally
has chat_history => sub { [] };

has ua => sub { Mojo::UserAgent->new };

# Shared i18n
has translations => sub { {} };
has _languages_cache => sub { undef };

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
    if (!-d $share_base) {
        # Try finding it relative to the backend if we're in srv/backend
        my $alt_share = $self->home->child('../../helm/share');
        $share_base = $alt_share if -d $alt_share;
    }
    my $share_dir  = Mojo::File->new($share_base)->child('locale');

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
            $c->app->translations($new_translations);
            $c->app->log->debug("Translations reloaded from $share_dir");
        }
    });

    # Initial load
    $self->load_translations();

    # Clear lang cache when translations change
    $self->helper(clear_lang_cache => sub ($c) { $c->app->_languages_cache(undef) });

    # Periodic check for hot-updates (every 5 minutes)
    Mojo::IOLoop->recurring(300 => sub { $self->load_translations() });

    $self->helper(languages => sub ($c) {
        if (my $cached = $c->app->_languages_cache) {
            return $cached;
        }

        my $trans = $c->app->translations;
        my %langs;
        for my $code (keys %$trans) {
            # Native name is stored in app.lang_<code_here> in its own file
            $langs{$code} = {
                name       => $trans->{$code}{app}{"lang_$code"} || uc($code),
                word_count => $c->app->scorer->word_count($code),
            };
        }
        $c->app->_languages_cache(\%langs);
        return \%langs;
    });

    $self->helper(t => sub ($c, $key, $lang = undef, $args = {}) {
        $lang ||= 'en';
        
        my $translations = $c->app->translations;
        # Traverse nested keys (e.g., 'app.error_word_not_found')
        my $val = $translations->{$lang} // $translations->{en} // {};
        for my $part (split /\./, $key) {
            $val = $val->{$part} if ref $val eq 'HASH';
        }
        if (defined $val && ref $val eq 'ARRAY') {
            $val = $val->[int(rand(@$val))];
        }
        $val = $key unless defined $val && !ref $val;

        # i18next-style interpolation: {{variable}}
        $val =~ s/\{\{(.*?)\}\}/$args->{$1} \/\/ "{missing:$1}"/ge;
        return $val;
    });

    # OAuth2 Configuration (Google & Discord)
    $self->plugin('OAuth2' => {
        google => {
            key    => $ENV{GOOGLE_CLIENT_ID}     || 'MISSING',
            secret => $ENV{GOOGLE_CLIENT_SECRET} || 'MISSING',
        },
        discord => {
            key    => $ENV{DISCORD_CLIENT_ID}     || 'MISSING',
            secret => $ENV{DISCORD_CLIENT_SECRET} || 'MISSING',
            authorize_url => 'https://discord.com/oauth2/authorize',
            token_url     => 'https://discord.com/api/oauth2/token',
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
    $auth->get('/discord')->to('auth#discord_login');
    $auth->get('/discord/callback')->to('auth#discord_callback')->name('discord_callback');
    $auth->get('/me')->to('auth#me');
    $auth->post('/logout')->to('auth#logout');
    $auth->post('/anonymous')->to('auth#anonymous_login');
    $auth->get('/passkey/challenge')->to('auth#passkey_challenge');
    $auth->post('/passkey/verify')->to('auth#passkey_verify');

    # WebSocket for game
    $r->websocket('/ws')->to('game#websocket');

    # Payment Routes
    $r->post('/payment/stripe/checkout')->to('payment#create_checkout_session');

    # HTTP API for stats
    $r->get('/players/leaderboard')->to('stats#leaderboard');

    # Global Broadcast Helper (broadcasts to EVERY connected client in EVERY game)
    $self->helper(broadcast_all_clients => sub ($c, $msg) {
        # Store in history if it's a chat message
    if ($msg->{type} eq 'chat') {
        my $history = $c->app->chat_history;
        my $limit   = $ENV{CHAT_HISTORY_SIZE} || 50;
        push @$history, $msg;
        shift @$history while @$history > $limit; # Use while to be safe
    }
    $c->app->broadcaster->announce_all_but($msg);
    });

    # Notification Helper
    $self->helper(notify_admin => sub ($c, $message) {
        my $app = $c->app;
        
        # 1. Discord Webhook
        if (my $webhook_url = $ENV{ADMIN_DISCORD_WEBHOOK}) {
            $app->ua->post($webhook_url => json => { content => $message } => sub ($ua, $tx) {
                if (my $err = $tx->error) {
                    $app->log->error("Discord notification failed: " . ($err->{message} || "Unknown error"));
                }
            });
        }

        # 2. SMS via Email Relay (Mint Mobile: 17169032417@tmomail.net)
        if (my $sms_email = $ENV{ADMIN_SMS_EMAIL}) {
             require Email::Stuffer;
             eval {
                 Email::Stuffer->from($ENV{MAIL_FROM} || 'noreply@wordwank.fazigu.org')
                              ->to($sms_email)
                              ->subject('Wordwank Alert')
                              ->text_body($message)
                              ->send;
                 $app->log->debug("Sent SMS notification to $sms_email");
             };
             if ($@) {
                 $app->log->error("Failed to send SMS notification: $@");
             }
        }
    });

    # Background task: Pre-populate games (ensure every language has a pending or active game)
    $self->helper(prepopulate_games => sub ($c) {
        my $schema = $c->app->schema;
        if (!$schema) {
            $c->app->log->debug("Skipping pre-population: no database connection");
            return;
        }

        my @langs = keys %{$c->app->translations};
        
        for my $lang (@langs) {
            # Check if there is an active (started) or pending (created but not started) game
            my $game;
            eval {
                $game = $schema->resultset('Game')->search({
                    finished_at => undef,
                    language    => $lang,
                }, { rows => 1 })->single;
            };
            if ($@) {
                $c->app->log->warn("Pre-population check failed for $lang: $@");
                next;
            }

            if (!$game) {
                $c->app->log->debug("Pre-populating pending game for $lang");
                my $rack;
                my $vals;
                eval {
                    $rack = $c->app->scorer->get_random_rack($lang);
                    $vals = $c->app->scorer->generate_tile_values($lang);
                };
                if ($@) {
                    $c->app->log->warn("Failed to generate rack/values for $lang: $@");
                    next;
                }
                
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
