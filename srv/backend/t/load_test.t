use strict;
use warnings;
use lib 'lib';
use Wordwank;
use Test::More;

warn "Attempting to create Wordwank app...\n";
my $app = Wordwank->new;
warn "App created.\n";

warn "Attempting to call startup...\n";
$app->startup;
warn "Startup finished.\n";

ok(1, "Got here");
done_testing();
