use v5.36;
use utf8;
use Mojo::URL;

my $base = "http://wordd:2345/validate/es/";
my $word = "ñame";

my $url1 = Mojo::URL->new($base);
$url1->path(lc($word));
say "1. path(string) replaces: " . $url1->to_string;

my $url2 = Mojo::URL->new($base);
$url2->path->merge(lc($word));
say "2. path->merge(string) appends: " . $url2->to_string;

my $url3 = Mojo::URL->new($base);
push @{$url3->path->parts}, lc($word);
say "3. push to parts: " . $url3->to_string;
