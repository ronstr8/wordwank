package Wordwank::Game::Scorer;
use Moose;
use v5.36;
use utf8;
use DateTime;
use YAML::XS qw(LoadFile);
use File::Spec;

# Cache for tile configurations keyed by language
has _tile_config_cache => (
    is      => 'ro',
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
    my $wordd_host = $ENV{WORDD_HOST} // 'wordd';
    my $wordd_port = $ENV{WORDD_PORT};
    if (!$wordd_port || $wordd_port =~ /\D/) {
        $wordd_port = 2345;
    }
    my $url = "http://$wordd_host:$wordd_port/config/$lang";
    
    my $http = HTTP::Tiny->new(timeout => 5);
    my $response = $http->get($url);
    
    if ($response->{success}) {
        my $config = eval { decode_json($response->{content}) };
        if ($config && $config->{tiles}) {
            warn "Loaded dynamic tile config for $lang from wordd.";
            return $config;
        }
        warn "Failed to parse tile config for $lang from $url: $@" if $@;
    } else {
        my $status = $response->{status} // 'unknown';
        my $reason = $response->{reason} // 'no reason provided';
        my $content = $response->{content} // '';
        warn "Failed to fetch tile config for $lang from $url: HTTP $status $reason";
        warn "Response body: " . substr($content, 0, 200) if $content;
    }

    # Fallback to English hardcoded tiles if wordd is unavailable or fails
    warn "Using hardcoded English fallback for $lang.";
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

# Generate letter values for a new game based on letter frequency
sub generate_letter_values ($self, $lang) {
    # Get current day of week in Buffalo, NY (America/New_York timezone)
    my $now = DateTime->now(time_zone => 'America/New_York');
    my $day_name = $now->day_name;  # Monday, Tuesday, etc.
    my $day_letter = uc(substr($day_name, 0, 1));  # M, T, W, T, F, S, S
    
    my %values;
    
    # Get configuration for specific language
    my $config = $self->_get_tile_config($lang);
    my $tiles = $config->{tiles} // {};
    my $unicorns = $config->{unicorns} // {};
    
    # Calculate total tile count
    my $total_tiles = 0;
    $total_tiles += $_ for values %$tiles;
    
    # Calculate frequency for each letter (excluding blanks)
    my %frequencies;
    for my $letter (keys %$tiles) {
        next if $letter eq '_';
        my $count = $tiles->{$letter};
        $frequencies{$letter} = $count / $total_tiles;
    }
    
    # Sort letters by frequency (rarest first for easier processing)
    my @sorted_letters = sort { $frequencies{$a} <=> $frequencies{$b} } keys %frequencies;
    
    # Top 2 rarest are unicorns (already set in config, worth 10 points)
    # Skip them in the distribution
    my %unicorn_set = map { $_ => 1 } keys %$unicorns;
    my @non_unicorn_letters = grep { !$unicorn_set{$_} } @sorted_letters;
    
    # Distribute remaining letters from 1-9 points based on frequency
    # Rarest non-unicorn gets 9, most common gets 1
    my $num_letters = scalar @non_unicorn_letters;
    for my $i (0 .. $#non_unicorn_letters) {
        my $letter = $non_unicorn_letters[$i];
        # Rarest (index 0) = 9 points, most common (last index) = 1 point
        # Linear distribution: points = 9 - (8 * i / (num_letters - 1))
        my $points = $num_letters > 1 
            ? int(9 - (8 * $i / ($num_letters - 1)) + 0.5)  # Round to nearest
            : 5;  # Fallback for edge case
        $values{$letter} = $points;
    }
    
    # Set unicorns to their configured point value (10)
    for my $letter (keys %$unicorns) {
        $values{$letter} = $unicorns->{$letter};
    }
    
    # Override: Day-of-week letter is 7 points (takes precedence over frequency-based scoring)
    $values{$day_letter} = 7;
    
    # Blank tile always 0
    $values{'_'} = 0;
    
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

# Cache for bags
has _bag_cache => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub _get_bag ($self, $lang) {
    if (my $cached = $self->_bag_cache->{$lang}) {
        return $cached;
    }
    
    my @bag;
    my $counts = $self->tile_counts($lang);
    for my $char (keys %$counts) {
        push @bag, ($char) x $counts->{$char};
    }
    
    $self->_bag_cache->{$lang} = \@bag;
    return \@bag;
}

sub is_vowel ($self, $char, $lang) {
    my $vowel_list = $self->vowels($lang) // [];
    my $uc_char = uc($char);
    return grep { $_ eq $uc_char } @$vowel_list;
}

sub get_random_rack ($self, $lang) {
    my $bag = $self->_get_bag($lang);
    my @rack;
    
    # Simple random draw
    my $rack_size = $ENV{RACK_SIZE} || 7;
    my @indices = (0 .. $#$bag);
    for (1 .. $rack_size) {
        my $idx = splice @indices, int(rand(@indices)), 1;
        push @rack, $bag->[$idx];
    }
    
    # Use configurable constraints
    my $min_v   = $ENV{MIN_VOWELS} // 1;
    my $min_c   = $ENV{MIN_CONSONANTS} // 1;
    
    my $v_count = grep { $self->is_vowel($_, $lang) } @rack;
    my $c_count = grep { $_ ne '_' && !$self->is_vowel($_, $lang) } @rack;

    unless ($v_count >= $min_v && $c_count >= $min_c) {
        return $self->get_random_rack($lang);
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
