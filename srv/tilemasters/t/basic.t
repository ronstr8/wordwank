use Test;
use lib 'lib';
use Tilemasters::Game;
use Tilemasters::Scorer;

# Basic test setup
plan 6;

# Test game initialization
my $game = Tilemasters::Game.new;
ok $game, 'Game object created';

# Test tile rack generation
my @rack = $game.generate-rack;
ok @rack.elems == 7, 'Rack contains 7 tiles';

# Test word validation
my $valid = $game.is-valid-word('HELLO');
ok $valid, 'Word validation works';

# Test scoring with case-sensitive blank tile handling
my $scorer = Tilemasters::Scorer.new;
my $score = $scorer.calculate-score('Hello'); # 'H' is normal, 'e' is blank, 'l' is normal, etc.
is $score, 7, 'Score calculation correctly handles blank tiles';

# Test duplicate word check (case-insensitive)
$game.add-played-word('HELLO');
my $duplicate = $game.is-duplicate-word('hello');
ok $duplicate, 'Duplicate word detection is case insensitive';

# Test final score calculation with duplicates and bonuses
my @plays = (
    { player => 'Alice', word => 'HELLO', score => $scorer.calculate-score('HELLO') },
    { player => 'Bob', word => 'hello', score => $scorer.calculate-score('HELLO') },
    { player => 'Charlie', word => 'QUIZ', score => $scorer.calculate-score('QUIZ') }
);

my @final-scores = $scorer.calculate-final-scores(@plays);
ok @final-scores.elems == 3, 'Final scores computed correctly';

# Done
done-testing;
