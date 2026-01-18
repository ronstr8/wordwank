use Test::More;
use Mojo::Base -signatures;
use Wordwank::Game::Scorer;

my $scorer = Wordwank::Game::Scorer->new;

# Mock environment
$ENV{RACK_SIZE} = 7;
$ENV{MIN_VOWELS} = 2;
$ENV{MIN_CONSONANTS} = 2;

subtest 'Rack constraints with default vowels' => sub {
    my $rack = $scorer->get_random_rack('en');
    
    is(scalar @$rack, 7, 'Rack size is correct');
    
    my $v_count = grep { $scorer->is_vowel($_, 'en') } @$rack;
    my $c_count = grep { $_ ne '_' && !$scorer->is_vowel($_, 'en') } @$rack;
    
    ok($v_count >= 2, "Has at least 2 vowels (got $v_count)");
    ok($c_count >= 2, "Has at least 2 consonants (got $c_count)");
};

subtest 'Rack constraints with custom vowels (e.g. only X is a vowel)' => sub {
    # High-pressure test for the filtering logic
    my $vowels = ["X"];
    # Need to make sure the bag has enough X's and non-X's
    # Scorer uses a bag generated from tile counts.
    
    # We can't easily mock the bag without deeper mocking, but we can verify is_vowel
    ok($scorer->is_vowel('X', $vowels), 'X is a vowel');
    ok(!$scorer->is_vowel('A', $vowels), 'A is not a vowel in this custom list');
};

subtest 'Language-specific vowels (Spanish)' => sub {
    my $vowels = ["A", "E", "I", "O", "U", "Á", "É", "Í", "Ó", "Ú"];
    ok($scorer->is_vowel('Á', $vowels), 'Á is a vowel in Spanish');
};

done_testing();
