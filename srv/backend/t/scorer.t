use strict;
use warnings;
use utf8;
use Test::More;
use lib 'lib';

use_ok('Wordwank::Game::Scorer');

my $scorer = Wordwank::Game::Scorer->new;
isa_ok($scorer, 'Wordwank::Game::Scorer');

subtest 'Rack Generation' => sub {
    my $lang = 'en';
    for (1..100) {
        my $rack = $scorer->get_random_rack($lang);
        is(scalar @$rack, $ENV{RACK_SIZE} || 7, "Rack size is correct at iteration $_");
        
        my $has_vowel     = grep { /[AEIOU]/ } @$rack;
        my $has_consonant = grep { !/[AEIOU_]/ } @$rack;
        
        ok($has_vowel, "Rack has at least one vowel at iteration $_");
        ok($has_consonant, "Rack has at least one consonant at iteration $_");
    }
};

subtest 'Scoring Logic' => sub {
    my $values = {
        A => 1, B => 3, C => 3, D => 2, E => 1,
        F => 4, G => 2, H => 4, I => 1, J => 8,
        K => 5, L => 1, M => 3, N => 1, O => 1,
        P => 3, Q => 10, R => 1, S => 1, T => 1,
        U => 1, V => 4, W => 4, X => 8, Y => 4,
        Z => 10, '_' => 0
    };

    is($scorer->calculate_score('CAT', $values), 5, 'Basic word score (C=3, A=1, T=1)');
    is($scorer->calculate_score('CaT', $values), 4, 'Word with blank (C=3, a=0, T=1)');
    is($scorer->calculate_score('cat', $values), 0, 'All blanks');
    is($scorer->calculate_score('', $values),    0, 'Empty word');
};

subtest 'Word Formation' => sub {
    my $rack = [qw(H E L L O _)];
    
    ok($scorer->can_form_word('HELLO', $rack), 'Can form HELLO');
    ok($scorer->can_form_word('HELL', $rack),  'Can form HELL');
    ok($scorer->can_form_word('HELPS', $rack) == 0, 'Cannot form HELPS with only one blank');
    
    $rack = [qw(H E L L O _ _)];
    ok($scorer->can_form_word('HELPS', $rack), 'Can form HELPS with two blanks');
    ok($scorer->can_form_word('HELLS', $rack), 'Can form HELLS using blank for S');
    
    $rack = [qw(A B C)];
    ok(!$scorer->can_form_word('D', $rack), 'Cannot form D without blank');
};

done_testing();
