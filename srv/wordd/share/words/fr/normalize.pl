#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

binmode(STDOUT, ':utf8');

while (<>) {
    s/^\s+|\s+$//g;

    next if length < 3;
    next if /[^a-zA-ZàâæçèéêëîïôœùûüÿÀÂÆÇÈÉÊËÎÏÔŒÙÛÜŸ-]/; # Allow hyphen for now to split

    # Normalize diacritics
    my $word = lc($_);
    
    # Ligatures
    $word =~ s/œ/oe/g;
    $word =~ s/æ/ae/g;
    
    # Accents
    $word =~ s/[àâ]/a/g;
    $word =~ s/[ç]/c/g;
    $word =~ s/[èéêë]/e/g;
    $word =~ s/[îï]/i/g;
    $word =~ s/[ô]/o/g;
    $word =~ s/[ùûü]/u/g;
    $word =~ s/[ÿ]/y/g;

    # Final filter: A-Z only
    next if $word =~ /[^a-z]/;
    
    print "$word\n";
}
