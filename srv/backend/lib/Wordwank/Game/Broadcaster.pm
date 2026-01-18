package Wordwank::Game::Broadcaster;
use Moose;
use v5.36;

has app => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

# announce($msg, \@recipients)
# recipients can be list of IDs or Player objects
sub announce ($self, $msg, $recipients) {
    return unless $recipients && ref $recipients eq 'ARRAY';

    for my $recipient (@$recipients) {
        my $pid = ref $recipient ? $recipient->id : $recipient;
        $self->_send_to_pid($pid, $msg);
    }
}

# announce_all_but($msg, \@exclude_list)
sub announce_all_but ($self, $msg, $exclude_list = []) {
    my %exclude = map { (ref $_ ? $_->id : $_) => 1 } @$exclude_list;

    for my $gid (keys %{$self->app->games}) {
        my $game_clients = $self->app->games->{$gid}{clients} // {};
        for my $pid (keys %$game_clients) {
            next if $exclude{$pid};
            $self->_send_to_pid($pid, $msg);
        }
    }
}

# Internal helper to send to a specific ID if connected
sub _send_to_pid ($self, $pid, $msg) {
    # We need to find the client. Clients are stored in app->games->{gid}{clients}{pid}
    # This is a bit inefficient to scan games, but typically there aren't many active games.
    for my $gid (keys %{$self->app->games}) {
        my $client = $self->app->games->{$gid}{clients}{$pid};
        if ($client && $client->tx) {
            $client->send({json => $msg});
            return; # Found and sent
        }
    }
}

# announce_to_game($msg, $game_id, $exclude_list)
sub announce_to_game ($self, $msg, $game_id, $exclude_list = []) {
    my %exclude = map { (ref $_ ? $_->id : $_) => 1 } @$exclude_list;
    my $game_clients = $self->app->games->{$game_id}{clients} // {};

    for my $pid (keys %$game_clients) {
        next if $exclude{$pid};
        my $client = $game_clients->{$pid};
        if ($client && $client->tx) {
            $client->send({json => $msg});
        }
    }
}

1;
