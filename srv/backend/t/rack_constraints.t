use Test::More;
use Test::MockModule;
use Mojo::Base -signatures;
use JSON::MaybeXS qw(encode_json);

# Mock HTTP::Tiny properly  
my $mock = Test::MockModule->new('HTTP::Tiny');
$mock->mock('get', sub {
    my ($self, $url) = @_;
    
    # Mock wordd /config/en endpoint
    if ($url =~ m{/config/en$}) {
        return {
            success => 1,
            content => encode_json({
                tiles => {
                    A => 9, B => 2, C => 2, D => 4, E => 12, F => 2, G => 3, H => 2,
                    I => 9, J => 1, K => 1, L => 4, M => 2, N => 6, O => 8, P => 2,
                    Q => 1, R => 6, S => 4, T => 6, U => 4, V => 2, W => 2, X => 1,
                    Y => 2, Z => 1, '_' => 2,
                },
                unicorns => { Q => 10, X => 10 },
                vowels => ['A', 'E', 'I', 'O', 'U'],
            })
        };
    }
    
    # Mock wordd /config/es endpoint
    if ($url =~ m{/config/es$}) {
        return {
            success => 1,
            content => encode_json({
                tiles => {
                    A => 12, B => 2, C => 4, D => 5, E => 12, F => 1, G => 2, H => 2,
                    I => 6, J => 1, K => 1, L => 4, M => 2, N => 5, Ñ => 1, O => 9,
                    P => 2, Q => 1, R => 5, S => 6, T => 4, U => 5, V => 1, W => 1,
                    X => 1, Y => 1, Z => 1, '_' => 2,
                },
                unicorns => { W => 10, K => 10 },
                vowels => ['A', 'E', 'I', 'O', 'U', 'Á', 'É', 'Í', 'Ó', 'Ú'],
            })
        };
    }
    
    return { success => 0, status => 404 };
});

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

subtest 'Vowel detection for English' => sub {
    ok($scorer->is_vowel('A', 'en'), 'A is a vowel in English');
    ok($scorer->is_vowel('E', 'en'), 'E is a vowel in English');
    ok(!$scorer->is_vowel('X', 'en'), 'X is not a vowel in English');
    ok(!$scorer->is_vowel('Z', 'en'), 'Z is not a vowel in English');
};

subtest 'Language-specific vowels (Spanish)' => sub {
    ok($scorer->is_vowel('A', 'es'), 'A is a vowel in Spanish');
    ok($scorer->is_vowel('Á', 'es'), 'Á is a vowel in Spanish');
    ok($scorer->is_vowel('É', 'es'), 'É is a vowel in Spanish');
    ok(!$scorer->is_vowel('N', 'es'), 'N is not a vowel in Spanish');
};

done_testing();
