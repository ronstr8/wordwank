package Wordwank::Web::Stats;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub leaderboard ($self) {
    my $app = $self->app;
    my $schema = $app->schema;
    
    $app->log->debug("Fetching leaderboard...");

    # Global Top 10
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

    my @leaders = map {
        {
            name  => $_->get_column('nickname'),
            score => int($_->get_column('total_score') // 0),
            plays => int($_->get_column('plays_count') // 0),
        }
    } $rs->all;

    # Optional personal stats
    my $personal;
    my $player_id = $self->param('player_id');
    
    # Fallback to session player if no ID provided in params but session exists
    if (!$player_id) {
        my $session_id = $self->cookie('ww_session');
        if ($session_id) {
            my $session = $schema->resultset('Session')->find($session_id);
            $player_id = $session->player_id if $session && $session->expires_at > DateTime->now;
        }
    }

    if ($player_id) {
        my $player_stats = $schema->resultset('Player')->find(
            { id => $player_id },
            {
                join     => 'plays',
                select   => [
                    'me.nickname',
                    { sum => 'plays.score', -as => 'total_score' },
                    { count => 'plays.id', -as => 'plays_count' }
                ],
                as       => [qw/nickname total_score plays_count/],
                group_by => [qw/me.id me.nickname/],
            }
        );
        if ($player_stats) {
            $personal = {
                name  => $player_stats->get_column('nickname'),
                score => int($player_stats->get_column('total_score') // 0),
                plays => int($player_stats->get_column('plays_count') // 0),
            };
        }
    }

    $self->render(json => {
        leaders => \@leaders,
        personal => $personal
    });
}

1;
