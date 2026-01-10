package Wordwank::Game::Scorer;
use Moose;
use v5.36;
use utf8;
use DateTime;

# Generate letter values for a new game based on new scoring rules
sub generate_letter_values {
    my $self = shift;
    
    # Get current day of week in Buffalo, NY (America/New_York timezone)
    my $now = DateTime->now(time_zone => 'America/New_York');
    my $day_name = $now->day_name;  # Monday, Tuesday, etc.
    my $day_letter = uc(substr($day_name, 0, 1));  # M, T, W, T, F, S, S
    
    my %values;
    my @vowels = qw(A E I O U);
    my @all_letters = ('A'..'Z');
    
    # Initialize all letters with random values 2-9
    for my $letter (@all_letters) {
        $values{$letter} = 2 + int(rand(8));  # Random from 2-9
    }
    
    # Override: Vowels always 1 point
    for my $vowel (@vowels) {
        $values{$vowel} = 1;
    }
    
    # Override: Q and Z always 10 points
    $values{Q} = 10;
    $values{Z} = 10;
    
    # Override: Day-of-week letter is 7 points (takes precedence over everything)
    $values{$day_letter} = 7;
    
    # Blank tile always 0
    $values{'_'} = 0;
    
    return \%values;
}

has tile_counts => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub {
        {
            A => 9, B => 2, C => 2, D => 4, E => 12, F => 2, G => 3, H => 2, I => 9, J => 1, K => 1, L => 4,
            M => 2, N => 6, O => 8, P => 2, Q => 1, R => 6, S => 4, T => 6, U => 4, V => 2, W => 2, X => 1,
            Y => 2, Z => 1,
        }
    }
);

has bag => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_build_bag',
);

sub _build_bag {
    my $self = shift;
    my @bag;
    my $counts = $self->tile_counts;
    for my $char (keys %$counts) {
        push @bag, ($char) x $counts->{$char};
    }
    return \@bag;
}

sub get_random_rack {
    my $self = shift;
    my $bag = $self->bag;
    my @rack;
    
    # Simple random draw
    my @indices = (0 .. $#$bag);
    for (1 .. 7) {
        my $idx = splice @indices, int(rand(@indices)), 1;
        push @rack, $bag->[$idx];
    }
    
    # Ensure at least one vowel
    unless (grep { /[AEIOU]/ } @rack) {
        return $self->get_random_rack;
    }
    
    return \@rack;
}

sub calculate_score {
    my ($self, $word, $custom_values) = @_;
    my $score = 0;
    
    # custom_values is now required (generated per game)
    return 0 unless $custom_values;
    
    for my $char (split //, uc($word)) {
        $score += $custom_values->{$char} // 0;
    }
    
    return $score;
}

sub can_form_word ($self, $word, $rack) {
    my %available;
    $available{$_}++ for @$rack;

    for my $char (split //, uc($word)) {
        if ($available{$char} && $available{$char} > 0) {
            $available{$char}--;
        }
        elsif ($available{'_'} && $available{'_'} > 0) {
            $available{'_'}--;
        }
        else {
            return 0;
        }
    }
    return 1;
}

sub uses_all_tiles ($self, $word, $rack) {
    # Check if the word uses all 7 tiles
    return length($word) == 7 && scalar(@$rack) == 7;
}

__PACKAGE__->meta->make_immutable;

1;
