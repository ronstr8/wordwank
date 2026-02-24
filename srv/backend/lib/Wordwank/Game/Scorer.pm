package Wordwank::Game::Scorer;
use Moose;
use v5.36;
use utf8;
use DateTime;
use YAML::XS qw(LoadFile);
use File::Spec;

# Cache for tile configurations keyed by language
has _tile_config_cache => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has _tile_values_cache => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

use HTTP::Tiny;
use JSON::MaybeXS qw(decode_json);

sub _get_tile_config ($self, $lang) {
    if (my $cached = $self->_tile_config_cache->{$lang}) {
        return $cached;
    }
    
    my $config = $self->_load_tile_config($lang);
    $self->_tile_config_cache->{$lang} = $config;
    return $config;
}

sub _load_tile_config ($self, $lang) {
    
    # wordd is the internal lexicon authority service
    my $host = $ENV{WORDD_HOST} || 'wordd';
    my $port = $ENV{WORDD_PORT} || 2345;
    my $url  = "http://$host:$port/config/$lang";
    
    my $ua = HTTP::Tiny->new(timeout => 2);
    my $response = $ua->get($url);
    
    my $config;
    if ($response->{success}) {
        eval { $config = decode_json($response->{content}) };
    }

    if ($config && $config->{tiles} && scalar(keys %{$config->{tiles}})) {
        warn "Loaded dynamic tile config for $lang from wordd.";
        return $config;
    }

    warn "Falling back to default tile config for $lang (wordd failed or returned empty)";
    # Fallback Scrabble-like distribution
    return {
        tiles => {
            A => 9, B => 2, C => 2, D => 4, E => 12, F => 2, G => 3, H => 2,
            I => 9, J => 1, K => 1, L => 4, M => 2, N => 6, O => 8, P => 2,
            Q => 1, R => 6, S => 4, T => 6, U => 4, V => 2, W => 2, X => 1,
            Y => 2, Z => 1, '_' => 2,
        },
        unicorns => { J => 10, Q => 10 },
        vowels => ['A', 'E', 'I', 'O', 'U'],
    };
}

# Generate tile values for a new game based on tile frequency
sub generate_tile_values ($self, $lang) {
    if (my $cached = $self->_tile_values_cache->{$lang}) {
        # Only return cache if it's the same day
        my $today = DateTime->now->ymd;
        return $cached->{values} if $cached->{date} eq $today;
    }

    my $config = $self->_get_tile_config($lang);
    my $tiles = $config->{tiles} // {};
    my %values;

    # Basic Scrabble-like values based on frequency
    for my $char (keys %$tiles) {
        next if $char eq '_';
        my $count = $tiles->{$char};
        
        # Lower frequency = higher value
        if ($count >= 10) { $values{$char} = 1 }
        elsif ($count >= 6) { $values{$char} = 2 }
        elsif ($count >= 4) { $values{$char} = 3 }
        elsif ($count >= 2) { $values{$char} = 4 }
        else { $values{$char} = 5 }
    }
    
    # Set unicorns to their configured point value (10)
    my $unicorns = $config->{unicorns} // {};
    for my $char (keys %$unicorns) {
        $values{$char} = $unicorns->{$char};
    }
    
    # Blank tile always 0
    $values{'_'} = 0;
    
    $self->_tile_values_cache->{$lang} = {
        date   => DateTime->now->ymd,
        values => \%values,
    };

    return \%values;
}

sub tile_counts ($self, $lang) {
    return $self->_get_tile_config($lang)->{tiles};
}

sub unicorns ($self, $lang) {
    return $self->_get_tile_config($lang)->{unicorns};
}

sub vowels ($self, $lang) {
    return $self->_get_tile_config($lang)->{vowels};
}

sub word_count ($self, $lang) {
    return $self->_get_tile_config($lang)->{word_count} // 0;
}

# Cache for bags
has _tile_bag_cache => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub _get_tile_bag ($self, $lang) {
    if (my $cached = $self->_tile_bag_cache->{$lang}) {
        return $cached;
    }
    
    my @bag;
    my $counts = $self->tile_counts($lang);
    for my $char (keys %$counts) {
        push @bag, ($char) x $counts->{$char};
    }
    
    $self->_tile_bag_cache->{$lang} = \@bag;
    return \@bag;
}

sub is_vowel ($self, $char, $lang) {
    my $vowel_list = $self->vowels($lang) // [];
    my $uc_char = uc($char);
    return grep { $_ eq $uc_char } @$vowel_list;
}

sub get_random_rack ($self, $lang, $size = 7, $depth = 0) {
    if ($depth > 5) {
        warn "Max rack generation depth reached for $lang, returning partial/fallback";
        return [ ('?') x ($ENV{RACK_SIZE} || 7) ];
    }

    my $config = $self->_get_tile_config($lang);
    my $bag_hash = ($config->{bag} && scalar(keys %{$config->{bag}})) ? $config->{bag} : $config->{tiles};
    
    my @bag;
    if ($bag_hash) {
        for my $char (keys %$bag_hash) {
            my $count = $bag_hash->{$char} // 0;
            if ($count > 0) {
                push @bag, ($char) x $count;
            }
        }
    }

    if (!@bag) {
        warn "Bag is empty for language $lang! Configuration error.";
        # emergency fallback if even wordd is wrong
        @bag = ('A'..'Z'); 
    }

    my @rack;
    # Simple random draw
    my $rack_size = $ENV{RACK_SIZE} || 7;
    my @indices = (0 .. $#bag);
    for (1 .. $rack_size) {
        last unless @indices;
        my $idx = splice @indices, int(rand(@indices)), 1;
        push @rack, $bag[$idx];
    }
    
    # Pad if somehow short
    push @rack, '?' while @rack < $rack_size;

    # Use configurable constraints
    my $min_v   = $ENV{MIN_VOWELS} // 1;
    my $min_c   = $ENV{MIN_CONSONANTS} // 1;
    
    my $v_count = grep { defined($_) && $self->is_vowel($_, $lang) } @rack;
    my $c_count = grep { defined($_) && $_ ne '_' && $_ ne '?' && !$self->is_vowel($_, $lang) } @rack;

    unless ($v_count >= $min_v && $c_count >= $min_c) {
        return $self->get_random_rack($lang, $size, $depth + 1);
    }
    
    return \@rack;
}


sub get_length_bonus ($self, $word) {
    my $len = length($word);
    return 0 if $len < 6;
    # 5 for 6, then double for each (6: 5, 7: 10, 8: 20, 9: 40...)
    return 5 * (2 ** ($len - 6));
}

sub calculate_score {
    my ($self, $word, $custom_values) = @_;
    my $score = 0;
    
    # custom_values is now required (generated per game)
    return 0 unless $custom_values;
    
    for my $char (split //, $word) {
        # Lowercase letters are blanks (0 points)
        next if $char =~ /[[:lower:]]/;
        $score += $custom_values->{uc($char)} // 0;
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

1;
