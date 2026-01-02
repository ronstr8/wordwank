unit module Tilemasters::Scorer;

class Scorer {
    my %letter-values = (
        A => 1, B => 3, C => 3, D => 2, E => 1, F => 4, G => 2, H => 4, I => 1, J => 8, K => 5, L => 1,
        M => 3, N => 1, O => 1, P => 3, Q => 10, R => 1, S => 1, T => 1, U => 2, V => 4, W => 4, X => 8,
        Y => 4, Z => 10, _ => 0
    );

    my %tile-counts = (
        A => 9, B => 2, C => 2, D => 4, E => 12, F => 2, G => 3, H => 2, I => 9, J => 1, K => 1, L => 4,
        M => 2, N => 6, O => 8, P => 2, Q => 1, R => 6, S => 4, T => 6, U => 4, V => 2, W => 2, X => 1,
        Y => 2, Z => 1
    );

    my @bag = %tile-counts.kv.map(-> $l, $c { $l xx $c }).flat;
    my @vowels = <A E I O U>;

    method get-random-rack() {
        loop {
            my @rack = @bag.pick(7);
            return @rack if @rack.grep({ $_ ∈ @vowels });
        }
    }

    method calculate-letter-value(Str $letter) {
      return 0 if $letter eq $letter.lc; # Blank tile
      return %letter-values{ .uc } // 0;
    }
    
    method calculate-word-value(Str $word) {
        [+] $word.comb.map({ self.calculate-letter-value($_) });
    }

    method calculate-final-scores(@plays) {
        my %seen;
        my %dupers; # Tracks who duped which word
        my @results;

        for @plays -> $play {
            my $normalized-word = $play<word>.lc;
            my %entry = (
                player => $play<player>, 
                word => $play<word>, 
                score => $play<score>, 
                exceptions => [],
                duped_by => []
            );

            if %seen{$normalized-word} {
                my $original-player = %seen{$normalized-word};
                %dupers{$normalized-word}.push($play<player>);
                %entry<score> = 0;
            } else {
                %seen{$normalized-word} = $play<player>;
                %dupers{$normalized-word} = [];
            }

            if $play<word>.chars == 7 {
                %entry<exceptions>.push("Used all tiles!" => 10);
                %entry<score> += 10;
            }

            @results.push(%entry);
        }

        # Attribute bonuses and dupe lists
        for @results -> %entry {
            my $word = %entry<word>.lc;
            if %seen{$word} eq %entry<player> {
                my $count = %dupers{$word}.elems;
                if $count > 0 {
                    %entry<score> += $count;
                    %entry<exceptions>.push("Subsequent dupes" => $count);
                    %entry<duped_by> = %dupers{$word};
                }
            }
        }

        my @unique-words = @results.grep({ $_<score> > 0 }).map({ $_<word>.lc });
        if @unique-words.elems == 1 {
            my $sole-word = @unique-words[0];
            my $total-dupes = @results.grep({ $_<score> == 0 }).elems;
            for @results -> %entry {
                if %entry<word>.lc eq $sole-word {
                    %entry<exceptions>.push("Sole unique word" => $total-dupes);
                    %entry<score> += $total-dupes;
                }
            }
        }

        @results .= sort({ -$_<score> });
        return @results;
    }
}
