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
    
    # Mock out background tasks that might interfere with tests before app creation
    {
        no warnings 'redefine';
        require Wordwank;
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
    
    _apply_mocks();

    my $t = Test::Mojo->new($base_mojo->app);
    $t->{test_stash} = [];

    my $ws_url = "/ws?lang=$language";
    $t->websocket_ok($ws_url => {'Accept-Language' => $language})
      ->status_is(101);
    
    # Pick up any message already buffered by Test::Mojo during handshake
    if ($t->message) {
        my $data = eval { decode_json($t->message->[1]) };
        if (ref $data eq 'HASH') {
            push @{$t->{test_stash}}, $data;
        }
    }

    # Attach listener to the transaction to catch future messages
    my $tx = $t->tx;
    $tx->on(message => sub {
        my ($tx, $msg) = @_;
        my $data = eval { decode_json($msg) };
        if (ref $data eq 'HASH') {
            push @{$t->{test_stash}}, $data;
        }
    });

    # Handshake Phase 1: Identity
    my $identity = wait_for_message($t, 'identity', 10);
    unless ($identity) {
        Test::More::fail("Timed out waiting for identity for $nickname");
        return ($t, undef, undef);
    }
    my $player_id = $identity->{id};
    
    # Now send join message
    $t->send_ok({json => {
        type => 'join',
        payload => {
            nickname => $nickname,
            language => $language,
        }
    }});
    
    # Handshake Phase 2: Game Start
    my $game_payload = wait_for_message($t, 'game_start', 10);
    unless ($game_payload) {
        Test::More::fail("Timed out waiting for game_start for $nickname");
        return ($t, $player_id, undef);
    }
    
    return ($t, $player_id, $game_payload);
}

sub wait_for_message {
    my ($t, $type, $timeout) = @_;
    $timeout //= 10;
    
    my $start = time;
    while (time - $start < $timeout) {
        # Check stash
        my $stash = $t->{test_stash} //= [];
        for (my $i = 0; $i < @$stash; $i++) {
            if (($stash->[$i]{type} // '') eq $type) {
                my $match = splice(@$stash, $i, 1);
                return $match->{payload};
            }
        }

        # Pulse the loop quietly but aggressively
        # One tick might not be enough on Windows for both client/server to process frames
        for (1..5) {
            $t->ua->ioloop->one_tick;
        }
        select(undef, undef, undef, 0.05); # Tiny sleep to yield
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
            # Support testing invalid words via magic string
            my $valid = ($word =~ /INVALID/i) ? 0 : 1;
            $cb->(Mojo::Message::Response->new(code => 200, body => encode_json({ 
                valid => $valid,
                definition => $valid ? "Mocked definition for $word" : undef,
            })));
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
        $schema->resultset('Play')->delete;
        $schema->resultset('Game')->delete;
        $schema->resultset('Player')->delete;
    };
}

1;
