use strict;
use warnings;
use Test::More;
use lib 'lib', 't/lib';

# Basic integration test setup verification
plan tests => 4;

# Test 1: Can we load the main app?
use_ok('Wordwank');

# Test 2: Can we load Test::Mojo?
use_ok('Test::Mojo');

# Test 3: Can we load our test helper?
use_ok('TestHelper', qw(get_test_mojo));

# Test 4: Can we instantiate the app?
my $t = get_test_mojo();
isa_ok($t, 'Test::Mojo', 'Test::Mojo instance created');

diag("Integration test setup successful!");
diag("App has schema: " . (defined $t->app->schema ? 'YES' : 'NO'));
diag("App has scorer: " . (defined $t->app->scorer ? 'YES' : 'NO'));
diag("App has broadcaster: " . (defined $t->app->broadcaster ? 'YES' : 'NO'));

done_testing();
