#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Encode;

use feature 'signatures';

no warnings 'redefine';

# hunspell_to_lexicon.pl - Convert Hunspell .dic files to Wordwank Lexicon format
# Usage: perl hunspell_to_lexicon.pl <filenames.dic> > <output_lexicon.txt>

binmode STDOUT, ":utf8";

my %WORDS;
my %AFFIXES; # $AFFIXES{SFX}{Flag} = [ { strip => '...', add => '...', cond => qr/.../ }, ... ]

process_file($_) for @ARGV;

print "$_\n" for sort keys %WORDS;

sub get_encoding ($input_file) {
    my $aff_file = $input_file;
    $aff_file =~ s/\.dic$/.aff/;
    
    if (-e $aff_file) {
        open my $fh, '<', $aff_file or return 'utf8';
        while (my $line = <$fh>) {
            if ($line =~ /^SET\s+([\w-]+)/) {
                my $enc = $1;
                close $fh;
                # Hunspell often says ISO8859-1 but Perl wants iso-8859-1
                return $enc;
            }
        }
        close $fh;
    }
    return 'utf8';
}

sub process_file ($input_file) {
    return unless -f $input_file;

    my $encoding = get_encoding($input_file);
    
    # Check if unmunch exists in PATH
    my $unmunch = `which unmunch 2>/dev/null`;
    chomp $unmunch;
    
    if ($unmunch && -x $unmunch) {
        my $aff_file = $input_file;
        $aff_file =~ s/\.dic$/.aff/;
        if (-e $aff_file) {
            open my $ph, '-|', "$unmunch \"$input_file\" \"$aff_file\"" or die "Failed to run unmunch: $!\n";
            while (my $line = <$ph>) {
                $line = decode($encoding, $line);
                chomp $line;
                add_word($line);
            }
            close $ph;
            return;
        }
    }

    # Fallback to manual expansion
    %AFFIXES = (); # Clear affixes for each new file
    parse_aff_file($input_file, $encoding);

    open my $fh, '<', $input_file or die "Failed to open $input_file: $!\n";
    while (my $line = <$fh>) {
        $line = decode($encoding, $line);
        process_line($line);
    }
    close $fh;
}

sub parse_aff_file ($dic_file, $encoding) {
    my $aff_file = $dic_file;
    $aff_file =~ s/\.dic$/.aff/;
    return unless -e $aff_file;

    open my $fh, '<', $aff_file or return;
    while (my $line = <$fh>) {
        $line = decode($encoding, $line);
        next if $line =~ /^\s*#|^\s*$/;
        
        # PFX flag cross_product number
        # PFX flag stripping prefix [condition]
        if ($line =~ /^(PFX|SFX)\s+(\S+)\s+([YN])\s+(\d+)/) {
            # Header line, can store cross-product if needed
        }
        elsif ($line =~ /^(PFX|SFX)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
            my ($type, $flag, $strip, $add, $cond) = ($1, $2, $3, $4, $5);
            $strip = '' if $strip eq '0';
            $add = '' if $add eq '0';
            
            # Simple condition conversion (Hunspell uses regex-like syntax)
            my $regex_cond;
            if ($cond eq '.') {
                $regex_cond = qr/./;
            } else {
                # Convert Hunspell char groups to Perl regex
                $regex_cond = $cond;
                # Suffixes match at the end, Prefixes at beginning
                if ($type eq 'SFX') {
                    $regex_cond = qr/$regex_cond$/;
                } else {
                    $regex_cond = qr/^$regex_cond/;
                }
            }

            push @{$AFFIXES{$type}{$flag}}, {
                strip => $strip,
                add   => $add,
                cond  => $regex_cond
            };
        }
    }
    close $fh;
}

sub process_line ($line) {
    chomp $line;
    return unless $line && $line =~ /^[[:alpha:]]/;

    # Strip Hunspell flags (e.g., word/SFX)
    my ($word, $flags_str) = split('/', $line);
    
    # Process base word
    add_word($word);

    return unless $flags_str;

    # Expansion logic
    my @flags = split('', $flags_str); # This assumes single-character flags, which is common
    # For more complex flags (FLAG long), we'd need to check the .aff header for FLAG type
    
    for my $flag (@flags) {
        # Try SFX
        if ($AFFIXES{SFX}{$flag}) {
            for my $rule (@{$AFFIXES{SFX}{$flag}}) {
                if ($word =~ $rule->{cond}) {
                    my $new_word = $word;
                    if ($rule->{strip}) {
                        my $s = $rule->{strip};
                        $new_word =~ s/$s$//;
                    }
                    $new_word .= $rule->{add};
                    add_word($new_word);
                }
            }
        }
        # Try PFX
        if ($AFFIXES{PFX}{$flag}) {
            for my $rule (@{$AFFIXES{PFX}{$flag}}) {
                if ($word =~ $rule->{cond}) {
                    my $new_word = $word;
                    if ($rule->{strip}) {
                        my $s = $rule->{strip};
                        $new_word =~ s/^$s//;
                    }
                    $new_word = $rule->{add} . $new_word;
                    add_word($new_word);
                }
            }
        }
    }
}

sub add_word ($word) {
    # Skip if it starts with a capital letter (proper nouns, etc.)
    return if $word =~ /^[[:upper:]]/;

    # Skip if it contains non-alphabetic characters
    return if $word =~ /[^[:alpha:]]/;

    # Skip anything longer than 8 letters
    return if length($word) > 8;
    
    # Needs to be at least 2 chars
    return if length($word) < 2;

    $WORDS{lc($word)}++;
}


