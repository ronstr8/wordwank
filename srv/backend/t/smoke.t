use v5.36;
use utf8;
use Test::More;
use Mojo::Base -strict;

ok(1, 'Basic test environment works');

my $word = "ÑAME";
is(length($word), 4, 'UTF-8 string length is correct');
is(uc($word), "ÑAME", 'UC works on Unicode');

done_testing();
