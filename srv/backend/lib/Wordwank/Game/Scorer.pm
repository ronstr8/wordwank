package Wordwank::Game::Scorer;
use Moose;
use v5.36;
use utf8;

has letter_values => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub {
        {
            A => 1, B => 3, C => 3, D => 2, E => 1, F => 4, G => 2, H => 4, I => 1, J => 8, K => 5, L => 1,
            M => 3, N => 1, O => 1, P => 3, Q => 10, R => 1, S => 1, T => 1, U => 2, V => 4, W => 4, X => 8,
            Y => 4, Z => 10, '_' => 0,
        }
    }
);

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
    
    for my $char (split //, uc($word)) {
        if ($custom_values && exists $custom_values->{$char}) {
            $score += $custom_values->{$char};
        } else {
            $score += $self->letter_values->{$char} // 0;
        }
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

__PACKAGE__->meta->make_immutable;

1;
