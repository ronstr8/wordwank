package TestHelper;
use strict;
use warnings;
use Mojo::Base -strict;
use Test::Mojo;
use Mojo::JSON qw(encode_json decode_json);
use UUID::Tiny qw(:std);
use DBI;

use Exporter 'import';
our @EXPORT = qw(
    get_test_mojo
    create_ws_client
    wait_for_message
    cleanup_test_games
);

my $singleton_t;

# Get a Test::Mojo instance with the app loaded using SQLite test database
sub get_test_mojo {
    my %args = @_;
    
    return $singleton_t if $singleton_t;

    # Set up test database connection string
    # Override the DATABASE_URL to use SQLite for testing
    $ENV{DATABASE_URL} = 'dbi:SQLite:dbname=:memory:';
    $ENV{DB_USER} = '';
    $ENV{DB_PASS} = '';
    $ENV{SHARE_DIR} = '../../helm/share';
    
    require Wordwank;
    
    # Mock out background tasks that might interfere with tests before app creation
    {
        no warnings 'redefine';
        *Wordwank::prepopulate_games = sub { 1 };
    }

    $singleton_t = Test::Mojo->new('Wordwank');
    
    # Deploy the schema to SQLite automatically from DBIx::Class Result classes
    eval {
        # Suppress noisy schema deployment logs
        my $old_level = $singleton_t->app->log->level;
        $singleton_t->app->log->level('warn');
        $singleton_t->app->schema->deploy;
        $singleton_t->app->log->level($old_level);
    };
    
    if ($@) {
        die "Failed to deploy test schema: $@";
    }
    
    return $singleton_t;
}

# Create a WebSocket client and perform initial handshake
# Returns: ($ws, $player_id, $game_payload)
sub create_ws_client {
    my %args = @_;
    my $base_mojo = $args{test_mojo} || get_test_mojo();
    my $nickname = $args{nickname} || 'TestPlayer' . int(rand(10000));
    my $language = $args{language} || 'en';
    
    # Disable external service calls during tests globally
    _apply_mocks();

    # Create a NEW Test::Mojo instance for each client linked to the same app
    my $t = Test::Mojo->new($base_mojo->app);

    # Start WebSocket connection
    $t->app->log->debug("TestHelper: Connecting to /ws for $nickname...");
    $t->websocket_ok('/ws')
      ->status_is(101)
      ->or(sub { die "WebSocket connection failed for $nickname" });
    
    # Handshake Phase 1: Identity
    $t->app->log->debug("TestHelper: Waiting for identity message for $nickname...");
    my $identity = wait_for_message($t, 'identity', 10);
    if (!$identity || !$identity->{id}) {
        die "Timed out waiting for personal identity message for $nickname";
    }
    my $player_id = $identity->{id};
    
    # Now send join message
    $t->app->log->debug("TestHelper: Sending join for $nickname (lang: $language)...");
    $t->send_ok({json => {
        type => 'join',
        payload => {
            nickname => $nickname,
            language => $language,
        }
    }});
    
    # Handshake Phase 2: Game Start
    $t->app->log->debug("TestHelper: Waiting for game_start message for $nickname...");
    my $game_payload = wait_for_message($t, 'game_start', 10);
    if (!$game_payload) {
        die "Timed out waiting for game_start message for $nickname";
    }
    $t->app->log->debug("TestHelper: Received game_start payload: " . Data::Dumper::Dumper($game_payload));
    $t->app->log->debug("TestHelper: Handshake complete for $nickname");
    return ($t, $player_id, $game_payload);
}

# Wait for a specific message type on a WebSocket (noise resilient)
sub wait_for_message {
    my ($t, $type, $timeout) = @_;
    $timeout //= 10;   # Increased default timeout to improve reliability
    
    my $start = time;
    while (time - $start < $timeout) {
        my $payload;
        my $found = 0;
        eval {
            $t->message_ok(1); 
            my $msg = $t->message;
            if ($msg) {
                my $data = eval { decode_json($msg->[1]) };
                if (ref $data eq 'HASH') {
                    if ($data->{type} && $data->{type} eq $type) {
                        $payload = $data->{payload};
                        $found = 1;
                    } else {
                        $t->app->log->debug("Received message of type '" . ($data->{type} // 'UNKNOWN') . "' while waiting for '$type'");
                    }
                }
            }
        };
        return $payload if $found;
        select(undef, undef, undef, 0.05);
    }
    
    return undef;
}

# Apply global monkey-patches to prevent external service calls during tests
sub _apply_mocks {
    {
        no warnings 'redefine';
        use Wordwank::Game::AI;
        use Wordwank::Web::Game;
        use Wordwank::Game::Scorer;
        use Mojo::Message::Response;

        # AI mocks
        *Wordwank::Game::AI::_request_candidates = sub { 
            my ($self, $url, $letters) = @_;
            $self->app->log->debug("AI " . $self->nickname . " MOCKED candidate fetch");
            return undef;
        } unless defined &Wordwank::Game::AI::_request_candidates_MOCKED;
        *Wordwank::Game::AI::_request_candidates_MOCKED = sub { 1 };

        # Game mocks (prevent wordd calls)
        *Wordwank::Web::Game::_validate_word_with_service = sub {
            my ($self, $word, $lang, $cb) = @_;
            $self->app->log->debug("MOCKED validation for '$word'");
            $cb->(Mojo::Message::Response->new(code => 200, body => "OK"));
        } unless defined &Wordwank::Web::Game::_validate_word_with_service_MOCKED;
        *Wordwank::Web::Game::_validate_word_with_service_MOCKED = sub { 1 };

        *Wordwank::Web::Game::_fetch_definition_with_service = sub {
            my ($self, $word, $lang, $cb) = @_;
            $cb->(Mojo::Message::Response->new(code => 404));
        } unless defined &Wordwank::Web::Game::_fetch_definition_with_service_MOCKED;
        *Wordwank::Web::Game::_fetch_definition_with_service_MOCKED = sub { 1 };

        *Wordwank::Web::Game::_fetch_suggested_word_with_service = sub {
            my ($self, $letters, $lang, $cb) = @_;
            $cb->(Mojo::Message::Response->new(code => 404));
        } unless defined &Wordwank::Web::Game::_fetch_suggested_word_with_service_MOCKED;
        *Wordwank::Web::Game::_fetch_suggested_word_with_service_MOCKED = sub { 1 };

        # Scorer mocks (prevent wordd config fetch)
        *Wordwank::Game::Scorer::_fetch_tile_config_from_service = sub {
            return { success => 0 }; # Fallback to internal Scrabble-like config
        } unless defined &Wordwank::Game::Scorer::_fetch_tile_config_from_service_MOCKED;
        *Wordwank::Game::Scorer::_fetch_tile_config_from_service_MOCKED = sub { 1 };
    }
}

# Cleanup test games from database and in-memory
sub cleanup_test_games {
    my ($t) = @_;
    $t //= get_test_mojo();
    
    # Clear in-memory state
    $t->app->games({});
    $t->app->chat_history([]);

    eval {
        my $schema = $t->app->schema;
        $schema->resultset('Game')->delete;
        $schema->resultset('Play')->delete;
        $schema->resultset('Player')->delete;
    };
}

1;
