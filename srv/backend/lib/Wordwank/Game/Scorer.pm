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
        warn "Failed to fetch tile config for $lang from $url: $response->{status} $response->{reason}";
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
    };
}

# Generate letter values for a new game based on new scoring rules
sub generate_letter_values ($self, $lang) {
    # Get current day of week in Buffalo, NY (America/New_York timezone)
    my $now = DateTime->now(time_zone => 'America/New_York');
    my $day_name = $now->day_name;  # Monday, Tuesday, etc.
    my $day_letter = uc(substr($day_name, 0, 1));  # M, T, W, T, F, S, S
    
    my %values;
    my @vowels = qw(A E I O U);
    
    # Get configuration for specific language
    my $config = $self->_get_tile_config($lang);
    my $unicorns = $config->{unicorns} // {};
    my @all_letters = keys %{$config->{tiles}};
    
    # Initialize all letters with random values 2-9
    for my $letter (@all_letters) {
        next if $letter eq '_';  # Skip blank
        $values{$letter} = 2 + int(rand(8));  # Random from 2-9
    }
    
    # Override: Vowels always 1 point
    for my $vowel (@vowels) {
        $values{$vowel} = 1 if exists $values{$vowel};
    }
    
    # Override: Unicorns always have their configured point value
    for my $letter (keys %$unicorns) {
        $values{$letter} = $unicorns->{$letter};
    }
    
    # Override: Day-of-week letter is 7 points (takes precedence over unicorns too)
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
    
    # Ensure at least one vowel and one consonant
    my $has_vowel     = grep { /[AEIOU]/   } @rack;
    my $has_consonant = grep { !/[AEIOU_]/ } @rack;

    unless ($has_vowel && $has_consonant) {
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
