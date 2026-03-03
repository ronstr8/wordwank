use strict;
use warnings;
use utf8;
use Test::More;
use DateTime;
use lib 'lib';

use_ok('Wordwank::Game::StateProcessor');

# Mock App
package MockApp {
    sub new { bless {}, shift }
    sub scorer {
        require Wordwank::Game::Scorer;
        return Wordwank::Game::Scorer->new;
    }
}

# Mock Play
package MockPlay {
    sub new { 
        my ($class, %args) = @_;
        bless \%args, $class;
    }
    sub get_column {
        my ($self, $col) = @_;
        return $self->{$col};
    }
}

my $app = MockApp->new;
my $processor = Wordwank::Game::StateProcessor->new(app => $app);

subtest 'Quick Wank Bonus calculation' => sub {
    my $game_start = DateTime->new(year => 2026, month => 3, day => 3, hour => 12, minute => 0, second => 0);
    $ENV{QUICK_BONUS_SECONDS} = 5;

    my @plays = (
        MockPlay->new(
            player_id  => 'p1',
            player     => 'Lightning',
            word       => 'CAT',
            score      => 5,
            created_at => $game_start->clone->add(seconds => 1), # Play at 1s
        ),
        MockPlay->new(
            player_id  => 'p2',
            player     => 'Slug',
            word       => 'DOG',
            score      => 5,
            created_at => $game_start->clone->add(seconds => 6), # Play at 6s (no bonus)
        ),
        MockPlay->new(
            player_id  => 'p3',
            player     => 'Medium',
            word       => 'BAT',
            score      => 5,
            created_at => $game_start->clone->add(seconds => 3), # Play at 3s
        ),
    );

    my $results = $processor->calculate_results(\@plays, 'en', $game_start);

    # p1 (Lightning): Play at 1s. Bonus = (5+1)-1 = 5. Total = 5 + 5 + 2 (unique) = 12.
    # WAIT: CAT, DOG, BAT are unique.
    # Base = 5. Unique = 2. 
    # p1 Quick Bonus = 5. Total = 12.
    # p2 Quick Bonus = 0. Total = 7.
    # p3 Quick Bonus = 3. Total = 10.

    my %res_by_player = map { $_->{player} => $_ } @$results;

    my $p1_bonus_obj = (grep { exists $_->{"Quick Bonus"} } @{$res_by_player{Lightning}{bonuses} // []})[0];
    my $p1_quick = $p1_bonus_obj ? $p1_bonus_obj->{"Quick Bonus"} : 0;
    is($p1_quick, 5, 'Player 1 got +5 quick bonus');
    is($res_by_player{Lightning}{score}, 12, 'Player 1 total score correct');

    my $p3_bonus_obj = (grep { exists $_->{"Quick Bonus"} } @{$res_by_player{Medium}{bonuses} // []})[0];
    my $p3_quick = $p3_bonus_obj ? $p3_bonus_obj->{"Quick Bonus"} : 0;
    is($p3_quick, 3, 'Player 3 got +3 quick bonus');
    is($res_by_player{Medium}{score}, 10, 'Player 3 total score correct');

    my $p2_bonus_obj = (grep { exists $_->{"Quick Bonus"} } @{$res_by_player{Slug}{bonuses} // []})[0];
    my $p2_quick = $p2_bonus_obj ? $p2_bonus_obj->{"Quick Bonus"} : 0;
    ok(!$p2_quick, 'Player 2 got no quick bonus');
    is($res_by_player{Slug}{score}, 7, 'Player 2 total score correct');
};

done_testing();
