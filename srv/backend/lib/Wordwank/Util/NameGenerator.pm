package Wordwank::Util::NameGenerator;
use Mojo::Base -base, -signatures;

my @CONSONANTS = qw(b c d f g h j k l m n p r s t v w z);
my @VOWELS     = qw(a e i o u);
my @C_BLENDS   = qw(bl br ch cl cr dr fl fr gl gr pl pr qu sc sk sl sm sn sp st sw th tr);
my @V_BLENDS   = qw(ae ai au ea ee ei eo eu ie io oa oe oi oo ou ui);

sub generate ($self, $seed_str = undef) {
    # If we have a seed (like a UUID), use its numeric hash to drive the randomness
    # otherwise use rand()
    if ($seed_str) {
        my $hash = 0;
        for my $char (split //, $seed_str) {
            $hash = (ord($char) + ($hash << 6) + ($hash << 16) - $hash) & 0xFFFFFFFF;
        }
        srand($hash);
    }

    my $syllables = 4 + int(rand(3));
    my $name = "";
	my $used_blends = 0;
	my $got_consonant = rand() > .5;
    
    for (my $i = 0; $i < $syllables; $i++) {
		my $grab_consonant = $got_consonant ? rand() < 0.01 : 1;

		if ($grab_consonant) {
			# Consonant (or blend)
			if ($used_blends < 2 && rand() < 0.3) {
				$used_blends++;
				$name .= $C_BLENDS[int(rand(@C_BLENDS))];
			} else {
				$name .= $CONSONANTS[int(rand(@CONSONANTS))];
			}

			$got_consonant = 1;
		} else {
			# Vowel (or blend)
			if ($used_blends < 2 && rand() < 0.2) {
				$used_blends++;
				$name .= $V_BLENDS[int(rand(@V_BLENDS))];
			} else {
				$name .= $VOWELS[int(rand(@VOWELS))];
			}

			$got_consonant = 0;
		}
    }

	# Optional tail consonant
	if (rand() < 0.4) {
		 $name .= $CONSONANTS[int(rand(@CONSONANTS))];
	}

    # Capitalize first letter
    return ucfirst($name);
}

1;
