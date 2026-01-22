package Wordwank::Util::NameGenerator;

use List::Util qw(any);
use Mojo::Base -base, -signatures;

my @CONSONANTS = qw(b c d f g h j k l m n p r s t v w z);
my @VOWELS     = qw(a e i o u);
my @C_BLENDS   = qw(bl br ch cl cr dr fl fr gl gr pl pr qu sc sk sl sm sn sp st sw th tr);
my @C_TRAILS   = qw(ch ck gn gh ld lk ll lm mn ng nd st sh sm st sp );
my @R_COMBOS   = @CONSONANTS[0..$#CONSONANTS-3];
my @V_BLENDS   = qw(ae ai au ea ee ei eo eu ie io oa oe oi oo ou ui);

sub generate ($self, $base_syllables = 4, $use_blends = 1, $seed_str = undef) {
    # If we have a seed (like a UUID), use its numeric hash to drive the randomness
    # otherwise use rand()
    if ($seed_str) {
        my $hash = 0;
        for my $char (split //, $seed_str) {
            $hash = (ord($char) + ($hash << 6) + ($hash << 16) - $hash) & 0xFFFFFFFF;
        }
        srand($hash);
    }

    my $syllables = $base_syllables + int(rand($base_syllables));
    my $name = '';
	my $used_blends = $use_blends ? 1_000_000 : 0;
	my $got_consonant = rand() > .5;
	my $played_letter = '';
    
    for (my $i = 0; $i < $syllables; $i++) {
		my $grab_consonant = $got_consonant ? rand() < 0.01 : 1;

		if ($grab_consonant) {
			# Consonant (or blend)
			if ($used_blends <= 2 && rand() < 0.45) {
				$used_blends++;
				$played_letter = $C_BLENDS[int(rand(@C_BLENDS))];
			} else {
				$played_letter = $CONSONANTS[int(rand(@CONSONANTS))];
			}

			$got_consonant = 1;
		} else {
			# Vowel (or blend)
			if ($used_blends <= 2 && rand() < 0.2) {
				$used_blends++;
				$played_letter = $V_BLENDS[int(rand(@V_BLENDS))];
			} else {
				$played_letter = $VOWELS[int(rand(@VOWELS))];
			}

			$got_consonant = 0;
		}

		$name .= $played_letter;
    }

	# Optional tail consonant
	if ( (any { $_ eq $played_letter } @VOWELS) && (rand() < 0.4) ) {
		my $r = rand();
		if ($r < 0.5) {
			$played_letter = $CONSONANTS[int(rand(@CONSONANTS))];
		} elsif ($r < 0.85) {
			$played_letter = $C_TRAILS[int(rand(@C_TRAILS))];
		} else {
			$played_letter = $R_COMBOS[int(rand(@R_COMBOS))];
		}
		$name .= $played_letter;
	}

    # Capitalize first letter
    return ucfirst($name);
}

1;
