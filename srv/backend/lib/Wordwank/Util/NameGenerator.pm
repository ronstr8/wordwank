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

    my $syllables = 2 + int(rand(2)); # 2 or 3 syllables
    my $name = "";
    
    for (my $i = 0; $i < $syllables; $i++) {
        # Consonant (or blend)
        if (rand() < 0.3) {
            $name .= $C_BLENDS[int(rand(@C_BLENDS))];
        } else {
            $name .= $CONSONANTS[int(rand(@CONSONANTS))];
        }
        
        # Vowel (or blend)
        if (rand() < 0.2) {
            $name .= $V_BLENDS[int(rand(@V_BLENDS))];
        } else {
            $name .= $VOWELS[int(rand(@VOWELS))];
        }
        
        # Optional tail consonant
        if (rand() < 0.4) {
             $name .= $CONSONANTS[int(rand(@CONSONANTS))];
        }
    }

    # Capitalize first letter
    return ucfirst($name);
}

1;
