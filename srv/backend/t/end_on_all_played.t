use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Data::Dumper;
use DateTime;
use Wordwank::Schema;

# Mock environment
$ENV{END_ON_ALL_PLAYED} = 'true';
$ENV{DATABASE_URL} = 'dbi:SQLite:dbname=:memory:';

my $t = Test::Mojo->new('Wordwank');
my $app = $t->app;

# Mock Wordd validation to be synchronous for unit testing
package MockResponse {
    sub new { 
        my ($class, $is_success, $json) = @_;
        return bless { is_success => $is_success, json => $json }, $class;
    }
    sub is_success { shift->{is_success} }
    sub json { shift->{json} }
}

require Wordwank::Service::Wordd;
{
    no strict 'refs';
    no warnings 'redefine';
    *Wordwank::Service::Wordd::validate = sub {
        my ($self, $word, $lang, $cb) = @_;
        $cb->(MockResponse->new(1, {
            is_valid => 1,
            word => $word,
            score => length($word),
        }));
    };
}

my $schema = $app->schema;
$schema->deploy;

# 1. Create a game
diag("Creating game...");
my $game = $schema->resultset('Game')->create({
    id => 'test-game-early-end',
    rack => ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
    letter_values => { A => 1, B => 1, C => 1, D => 1, E => 1, F => 1, G => 1, H => 1 },
    language => 'en',
    started_at => DateTime->now,
});
diag("Game created: " . $game->id);

# 2. Add two players and connect them
diag("Creating players...");
my $p1 = $schema->resultset('Player')->create({ id => 'p1', nickname => 'Player 1' });
my $p2 = $schema->resultset('Player')->create({ id => 'p2', nickname => 'Player 2' });
diag("Players created.");

# Mock controller with necessary methods
package MockController {
    sub new { 
        my ($class, $app) = @_;
        return bless { app => $app }, $class;
    }
    sub app { shift->{app} }
    sub t   { shift->app->t(@_) }
    sub send { 1 } # No-op for testing
    sub tx   { 1 } # Mock transaction for testing
    sub broadcast_to_game { shift->app->broadcaster->announce_to_game(@_) }
}

my $c1 = MockController->new($app);
my $c2 = MockController->new($app);

# Inject game state manually since we aren't doing full WS handshake here for the unit check
$app->games->{$game->id} = {
    state => $game,
    clients => {
        p1 => $c1,
        p2 => $c2,
    },
    time_left => 30,
};
diag("Game state injected.");

# 3. Simulate first play
diag("Simulating first play...");
eval {
    $app->game_manager->_perform_play($c1, $p1, {}, 'AB', $app->games->{$game->id}, $game);
};
if ($@) {
    diag("First play failed: $@");
}

# Verify game NOT finished
my $check_game = $schema->resultset('Game')->find($game->id);
ok(!$check_game->finished_at, "Game still active after 1/2 players played");

# 4. Simulate second play
diag("Simulating second play...");
eval {
    $app->game_manager->_perform_play($c2, $p2, {}, 'CD', $app->games->{$game->id}, $game);
};
if ($@) {
    diag("Second play failed: $@");
}

# Verify game IS finished
my $updated_game = $schema->resultset('Game')->find($game->id);
diag("Game finished_at is: " . ($updated_game->finished_at // "UNDEF"));
ok($updated_game->finished_at, "Game ended early after all players played");

diag("Test complete.");
done_testing();
