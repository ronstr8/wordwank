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

    open my $fh, '<', $input_file or die "Failed to open $input_file: $!\n";

    while (my $line = <$fh>) {
        # Decode the line based on the detected encoding
        $line = decode($encoding, $line);
        process_line($line);
    }

    close $fh;
}

sub process_line ($line) {
    chomp $line;
    return unless $line && $line =~ /^[[:alpha:]]{2,}/;

    # Strip Hunspell flags (e.g., word/SFX)
    my ($word) = split('/', $line);

    # Skip if it starts with a capital letter (proper nouns, etc.)
    return if $word =~ /^[[:upper:]]/;

    # Skip if it contains non-alphabetic characters (optional, but good for clean lexicons)
    return if $word =~ /[^[:alpha:]]/;

    # Skip anything longer than 8 letters
    return if length($word) > 8;

    $WORDS{$word}++;
}


