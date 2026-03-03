use strict;
use warnings;
use utf8;
use Test::More;
use lib 'lib';
use Wordwank::Game::Scorer;

my $scorer = Wordwank::Game::Scorer->new();

sub calculate_prefix {
    my ($word, $elapsed, $quick_bonus_seconds, $rack_size) = @_;
    my @emojis;
    
    # ⚡ Quick Bonus
    push @emojis, '⚡' if $elapsed <= $quick_bonus_seconds;

    # 💯 Full Rack
    push @emojis, '💯' if length($word) >= $rack_size;

    # ✨ Extra Letters (Dynamic threshold)
    my $len_bonus = $scorer->get_length_bonus($word, $rack_size);
    push @emojis, '✨' if $len_bonus > 0;

    # 📅 Daily Bonus
    my $bonus_char = $scorer->get_daily_bonus_char();
    push @emojis, '📅' if index(uc($word), $bonus_char) != -1;
    
    return @emojis ? join('', @emojis) . ' ' : '';
}

subtest 'Emoji Prefix Logic' => sub {
    my $quick_bonus_seconds = 5;

    # Tuesday = 'T' is the bonus char
    is(calculate_prefix('CAT', 1, $quick_bonus_seconds, 7), '⚡📅 ', 'Quick play on standard 7 with T gets lightning + calendar');
    is(calculate_prefix('WORDWANK', 6, $quick_bonus_seconds, 8), '💯✨ ', 'Full rack (8) no T gets 100 + sparkles');
    
    # New threshold for 8 rack is 5 letters (int(8/2)+1 = 5)
    is(calculate_prefix('WANK', 6, $quick_bonus_seconds, 8), '', '4 letters on 8 rack no T gets nothing');
    is(calculate_prefix('WANKER', 6, $quick_bonus_seconds, 8), '✨ ', '6 letters on 8 rack no T gets sparkles');
    
    is(calculate_prefix('CAT', 6, $quick_bonus_seconds, 7), '📅 ', 'Normal play on standard 7 with T gets calendar');
    is(calculate_prefix('WANKER', 1, $quick_bonus_seconds, 8), '⚡✨ ', 'Quick + 6 letters on 8 rack no T');
};

done_testing();
