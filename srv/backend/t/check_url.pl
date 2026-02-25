use v5.36;
use utf8;
use Mojo::URL;

# Target: http://wordd:2345/validate/es/ñame
my $lang = 'es';
my $word = 'ÑAME';
my $wordd_host = 'wordd';
my $wordd_port = 2345;

my $wordd_url = Mojo::URL->new("http://$wordd_host:$wordd_port/validate/$lang/")
                         ->path(lc($word));

say "1. Result using ->path(lc(\$word)): " . $wordd_url->to_string;

my $wordd_url2 = Mojo::URL->new("http://$wordd_host:$wordd_port/validate/$lang/");
$wordd_url2->path->append(lc($word));

say "2. Result using ->path->append(lc(\$word)): " . $wordd_url2->to_string;
