package Wordwank::Util::NameGenerator;
use Mojo::Base -base, -signatures;

my @CONSONANTS = qw(b c d f g h j k l m n p r s t v w z);
my @VOWELS     = qw(a e i o u);

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

    my $length = 5 + int(rand(3)); # 5, 6, or 7
    my $name = "";
    
    # Simple C-V-C pattern
    for (my $i = 0; $i < $length; $i++) {
        if ($i % 2 == 0) {
            $name .= $CONSONANTS[int(rand(@CONSONANTS))];
        } else {
            $name .= $VOWELS[int(rand(@VOWELS))];
        }
    }

    # Capitalize first letter
    return ucfirst($name);
}

1;
