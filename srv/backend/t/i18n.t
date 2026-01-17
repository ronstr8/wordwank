use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use File::Spec;
use Mojo::JSON qw(encode_json);

# Mock environment
my $base_dir = tempdir(CLEANUP => 1);
my $locale_dir = File::Spec->catdir($base_dir, 'locale');
mkdir $locale_dir;
$ENV{SHARE_DIR} = $base_dir;

# Create dummy locale
my $en_file = File::Spec->catfile($locale_dir, 'en.json');
Mojo::File->new($en_file)->spurt(encode_json({
    test => {
        key => "Hello {{name}}",
        nested => { key => "Deep" }
    }
}));

my $t = Test::Mojo->new('Wordwank');

subtest 'Basic Translation' => sub {
    is($t->app->t('test.key', 'en', { name => 'World' }), "Hello World", "Simple interpolation");
    is($t->app->t('test.nested.key', 'en'), "Deep", "Nested key lookup");
    is($t->app->t('nonexistent', 'en'), "nonexistent", "Fallback to key name");
};

subtest 'Missing Placeholders' => sub {
    is($t->app->t('test.key', 'en'), "Hello {missing:name}", "Missing placeholder indicator");
};

subtest 'Hot Reload' => sub {
    # Update file
    Mojo::File->new($en_file)->spurt(encode_json({
        test => { key => "Updated {{name}}" }
    }));
    
    # Trigger manual reload for test (since recurring timer is slow)
    $t->app->load_translations();
    
    is($t->app->t('test.key', 'en', { name => 'User' }), "Updated User", "Hot reload success");
};

done_testing();
