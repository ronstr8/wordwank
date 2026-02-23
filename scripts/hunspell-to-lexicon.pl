#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use feature 'signatures';

no warnings 'redefine';

# hunspell_to_lexicon.pl - Convert Hunspell .dic files to Wordwank Lexicon format
# Usage: perl hunspell_to_lexicon.pl <@filenames.dic> > <output_lexicon.txt>

my %WORDS;

process_file($_) for @ARGV;

print "$_\n" for sort keys %WORDS;

sub process_file ($input_file) {
	open my $fh, $input_file or die "Failed to open $input_file: $!\n";

	while (my $line = <$fh>) {
		process_line($line);
	}

	close $fh;
}

sub process_line ($line) {
    chomp $line;
    return unless $line;

    # Strip Hunspell flags (e.g., word/SFX)
    my ($word) = split('/', $line);

    # Skip if it starts with a capital letter (proper nouns, curses/politically incorrect often capitalized)
    return if $word =~ /^[[:upper:]]/; # Supports Latin and basic Cyrillic capitals

	# Skip anything longer than 8 letters, a number which matters
	# to Wordwankers, but should be generic and configurable
	return if $word =~ /^[[:alpha:]]{9,}/;

	$WORDS{$word}++;
}
