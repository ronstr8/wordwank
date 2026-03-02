#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use File::Basename 'dirname';
use File::Spec::Functions qw(catdir catfile);
use Mojo::Log;

# Setup include path
my $lib = catdir(dirname(__FILE__), '..', 'lib');
push @INC, $lib;

require Wordwank::Schema;

my $log = Mojo::Log->new;
my $dsn = $ENV{DATABASE_URL} || 'dbi:Pg:dbname=wordwank;host=postgresql';
my $user = $ENV{DB_USER};
my $pass = $ENV{DB_PASS};

$log->info("Starting migrations on $dsn...");

my $schema = Wordwank::Schema->connect($dsn, $user, $pass, {
    pg_enable_utf8 => 1,
    quote_names    => 1,
    RaiseError     => 1,
});

# Ensure migration tracking table exists
$schema->storage->dbh->do(q{
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
});

my $migrations_dir = catdir(dirname(__FILE__), '..', 'schema', 'migrations');
opendir(my $dh, $migrations_dir) or die "Could not open migrations dir: $!";
my @files = sort grep { /\.sql$/ } readdir($dh);
closedir($dh);

for my $file (@files) {
    my ($version) = $file =~ /^(\d+)/;
    next unless $version;

    my $already_applied = $schema->storage->dbh->selectrow_array(
        "SELECT 1 FROM schema_migrations WHERE version = ?",
        undef, $version
    );

    if ($already_applied) {
        $log->debug("Migration $file already applied, skipping.");
        next;
    }

    $log->info("Applying migration $file...");
    my $sql_path = catfile($migrations_dir, $file);
    my $sql = do {
        local $/;
        open my $fh, '<:utf8', $sql_path or die "Could not open $sql_path: $!";
        <$fh>;
    };

    eval {
        $schema->storage->dbh_do(sub {
            my ($storage, $dbh) = @_;
            # Split by semicolon and run each statement if needed, 
            # but for simplicity we run the whole block.
            # Note: This doesn't handle complex SQL with semicolons in strings well.
            $dbh->do($sql);
            $dbh->do("INSERT INTO schema_migrations (version) VALUES (?)", undef, $version);
        });
        $log->info("Migration $file applied successfully.");
    };
    if ($@) {
        $log->error("FAILED to apply migration $file: $@");
        exit 1;
    }
}

$log->info("All migrations completed successfully.");
