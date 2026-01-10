package Wordwank::Web::Stats;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub leaderboard ($self) {
    my $app = $self->app;
    my $schema = $app->schema;
    
    $app->log->debug("Fetching leaderboard...");

    # Robust aggregation for Postgres
    my $rs = $schema->resultset('Player')->search(
        {},
        {
            join     => 'plays',
            select   => [
                'me.nickname',
                { sum => 'plays.score', -as => 'total_score' },
                { count => 'plays.id', -as => 'plays_count' }
            ],
            as       => [qw/nickname total_score plays_count/],
            group_by => [qw/me.id me.nickname/],
            order_by => [ { -desc => 'total_score' } ],
            limit    => 10,
        }
    );

    my @stats = map {
        {
            name  => $_->get_column('nickname'),
            score => int($_->get_column('total_score') // 0),
            plays => int($_->get_column('plays_count') // 0),
        }
    } $rs->all;

    $app->log->debug("Found " . scalar(@stats) . " leaders");
    $self->render(json => \@stats);
}

1;
