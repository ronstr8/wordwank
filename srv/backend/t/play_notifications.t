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
    
    return @emojis ? join('', @emojis) . ' ' : '';
}

subtest 'Emoji Prefix Logic' => sub {
    my $quick_bonus_seconds = 5;

    is(calculate_prefix('CAT', 1, $quick_bonus_seconds, 7), '⚡ ', 'Quick play on standard 7 gets lightning only');
    is(calculate_prefix('WORDWANK', 6, $quick_bonus_seconds, 8), '💯✨ ', 'Full rack (8) gets 100 + sparkles (8 >= 5)');
    
    # New threshold for 8 rack is 5 letters (int(8/2)+1 = 5)
    is(calculate_prefix('WANK', 6, $quick_bonus_seconds, 8), '', '4 letters on 8 rack gets no sparkles');
    is(calculate_prefix('WANKER', 6, $quick_bonus_seconds, 8), '✨ ', '6 letters on 8 rack gets sparkles');
    
    is(calculate_prefix('CAT', 6, $quick_bonus_seconds, 7), '', 'Normal play on standard 7 gets nothing');
    is(calculate_prefix('WANKER', 1, $quick_bonus_seconds, 8), '⚡✨ ', 'Quick + 6 letters on 8 rack');
};

done_testing();
