use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Data::Dumper;
use DateTime;
use Wordwank::Schema;

# Mock environment
$ENV{DATABASE_URL} = 'dbi:SQLite:dbname=:memory:';
$ENV{QUICK_BONUS_SECONDS} = 5;

my $t = Test::Mojo->new('Wordwank');
my $app = $t->app;
my $schema = $app->schema;
$schema->deploy;

# 1. Create a game started 2 seconds ago
my $started_at = DateTime->now->subtract(seconds => 2);
diag("Creating game started at: " . $started_at);

my $game = $schema->resultset('Game')->create({
    id => 'test-game-quick-bonus',
    rack => ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'],
    letter_values => { A => 1, B => 1, C => 1, D => 1, E => 1, F => 1, G => 1, H => 1 },
    language => 'en',
    started_at => $started_at,
});

# 2. Add players
my $p1 = $schema->resultset('Player')->create({ id => 'p1', nickname => 'Fazigu' });
my $p2 = $schema->resultset('Player')->create({ id => 'p2', nickname => 'Flash' });

# 3. Create plays
# Play 1: Created NOW (2s since start) -> Should get bonus
diag("Creating play for Fazigu...");
my $play1 = $schema->resultset('Play')->create({
    game_id   => $game->id,
    player_id => $p1->id,
    word      => 'QUICK',
    score     => 5,
    created_at => DateTime->now,
});

# Play 2: Created far in future or far in past? 
# Wait, let's create a "Slow" play
diag("Creating slow play for Flash...");
my $play2 = $schema->resultset('Play')->create({
    game_id   => $game->id,
    player_id => $p2->id,
    word      => 'SLOW',
    score     => 4,
    created_at => DateTime->now->add(seconds => 10),
});

# 4. Process results
diag("Calculating results...");
my @plays = $schema->resultset('Play')->search(
    { 'me.game_id' => $game->id },
    { prefetch => 'player' }
)->all;

my $results = $app->state_processor->calculate_results(\@plays, 'en', $game->started_at, 8);

# diag(Dumper($results));

# 5. Assertions
my ($fazigu_res) = grep { $_->{player_id} eq 'p1' } @$results;
my ($flash_res)  = grep { $_->{player_id} eq 'p2' } @$results;

ok($fazigu_res, "Found result for Fazigu");
ok($flash_res, "Found result for Flash");

# Check Fazigu's Quick Bonus
my ($quick_bonus) = grep { exists $_->{"Quick Bonus"} } @{$fazigu_res->{bonuses}};
ok($quick_bonus, "Fazigu got Quick Bonus itemized") or diag(Dumper($fazigu_res->{bonuses}));
is($quick_bonus->{"Quick Bonus"}, 5, "Fazigu got 5 pts for Quick Bonus");
is($fazigu_res->{score}, 5 + 5 + 2, "Fazigu total: 5 (base) + 5 (quick) + 2 (unique)");

# Check Flash's Quick Bonus (should be 0/missing)
my ($flash_quick) = grep { exists $_->{"Quick Bonus"} } @{$flash_res->{bonuses}};
ok(!$flash_quick, "Flash did NOT get Quick Bonus");
is($flash_res->{score}, 4 + 2, "Flash total: 4 (base) + 2 (unique)");

diag("Test complete.");
done_testing();
