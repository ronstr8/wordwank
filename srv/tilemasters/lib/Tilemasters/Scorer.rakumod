unit module Tilemasters::Scorer;

class Scorer {
    my %letter-values = (
        A => 1, B => 3, C => 3, D => 2, E => 1, F => 4, G => 2, H => 4, I => 1, J => 8, K => 5, L => 1,
        M => 3, N => 1, O => 1, P => 3, Q => 10, R => 1, S => 1, T => 1, U => 2, V => 4, W => 4, X => 8,
        Y => 4, Z => 10, _ => 0
    );

    method calculate-letter-value(Str $letter) {
      return 0 if $letter eq $letter.lc; # Blank tile
      return %letter-values{ .uc } // 0;
    }
    
    method calculate-word-value(Str $word) {
        [+] $word.comb.map({ self.calculate-letter-value($_) });
    }

    method calculate-final-scores(@plays) {
        my %seen;
        my %original-scorers;
        my $dupe-count = 0;
        my @results;

        for @plays -> $play {
            my $normalized-word = $play<word>.lc;
            my %entry = (player => $play<player>, word => $play<word>, score => $play<score>, exceptions => []);

            if %seen{$normalized-word} {
                %original-scorers{%seen{$normalized-word}} += 1;
                $dupe-count += 1;
                %entry<score> = 0;
            } else {
                %seen{$normalized-word} = $play<player>;
            }

            if $play<word>.chars == 7 {
                %entry<exceptions>.push("Used all tiles!" => 10);
                %entry<score> += 10;
            }

            @results.push(%entry);
        }

        for %original-scorers.keys -> $player {
            for @results -> %entry {
                if %entry<player> eq $player {
                    %entry<score> += %original-scorers{$player};
                }
            }
        }

        my @unique-words = @results.grep({ $_<score> > 0 }).map({ $_<word>.lc });
        if @unique-words.elems == 1 {
            my $sole-word = @unique-words[0];
            for @results -> %entry {
                if %entry<word>.lc eq $sole-word {
                    %entry<exceptions>.push("Sole unique word" => $dupe-count);
                    %entry<score> += $dupe-count;
                }
            }
        }

        @results .= sort({ -$_<score> });
        return @results;
    }
}
