package Wordwank;
use Mojo::Base 'Mojolicious', -signatures;
use Wordwank::Schema;
use Wordwank::Game::Scorer;

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
}

1;
