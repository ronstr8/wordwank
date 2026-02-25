package TestHelper;
use strict;
use warnings;
use Mojo::Base -strict;
use Test::Mojo;
use Mojo::JSON qw(encode_json decode_json);
use UUID::Tiny qw(:std);
use DBI;

use Exporter 'import';
our @EXPORT_OK = qw(
    get_test_mojo
    create_ws_client
    wait_for_message
    cleanup_test_games
);

# Get a Test::Mojo instance with the app loaded using SQLite test database
sub get_test_mojo {
    my %args = @_;
    
    # Set up test database connection string
    # Override the DATABASE_URL to use SQLite for testing
    local $ENV{DATABASE_URL} = 'dbi:SQLite:dbname=:memory:';
    local $ENV{DB_USER} = '';
    local $ENV{DB_PASS} = '';
    local $ENV{SHARE_DIR} = '../../helm/share';
    
    require Wordwank;
    my $t = Test::Mojo->new('Wordwank');
    
    # Deploy the schema to SQLite automatically from DBIx::Class Result classes
    # This eliminates the need to maintain a separate SQLite schema file
    eval {
        $t->app->schema->deploy;
    };
    
    if ($@) {
        die "Failed to deploy test schema: $@";
    }
    
    return $t;
}

# Create a WebSocket client and perform initial handshake
# Returns: ($ws, $player_id)
sub create_ws_client {
    my %args = @_;
    my $t = $args{test_mojo} || get_test_mojo();
    my $nickname = $args{nickname} || 'TestPlayer' . int(rand(10000));
    my $language = $args{language} || 'en';
    
    # Start WebSocket connection
    $t->websocket_ok('/ws')
      ->status_is(101)
      ->or(sub { die "WebSocket connection failed" });
    
    # Wait for identity message (sent automatically by server)
    my $player_id;
    $t->message_ok->or(sub { die "No identity message received" });
    
    my $identity = decode_json($t->message->[1]);
    if ($identity->{type} eq 'identity') {
        $player_id = $identity->{payload}{id};
    } else {
        die "Expected 'identity' message, got: " . ($identity->{type} || 'unknown');
    }
    
    # Now send join message
    my $join_msg = encode_json({
        type => 'join',
        payload => {
            nickname => $nickname,
            language => $language,
        }
    });
    
    $t->send_ok($join_msg);
    
    # Wait for game_start confirmation
    $t->message_ok->or(sub { die "No game_start confirmation received" });
    
    my $response = decode_json($t->message->[1]);
    unless ($response->{type} eq 'game_start') {
        die "Expected 'game_start' message, got: " . ($response->{type} || 'unknown');
    }
    
    return ($t, $player_id, $response->{payload});
}

# Wait for a specific message type on a WebSocket
# Returns the message payload or undef on timeout
sub wait_for_message {
    my ($t, $type, $timeout) = @_;
    $timeout //= 5;
    
    my $start = time;
    while (time - $start < $timeout) {
        eval {
            $t->message_ok;
            my $msg = decode_json($t->message->[1]);
            return $msg->{payload} if $msg->{type} eq $type;
        };
        select(undef, undef, undef, 0.1); # Sleep 100ms
    }
    
    return undef;
}

# Cleanup test games from database
sub cleanup_test_games {
    my ($t) = @_;
    $t //= get_test_mojo();
    
    # For SQLite in-memory database, no cleanup needed as it's destroyed when connection closes
    # But we can still delete recent test data for good measure
    eval {
        my $schema = $t->app->schema;
        
        # Delete all test games
        $schema->resultset('Game')->delete;
        $schema->resultset('Play')->delete;
    };
}

1;

