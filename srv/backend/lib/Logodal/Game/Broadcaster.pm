package Logodal::Game::Broadcaster;
use Moose;
use Mojo::JSON qw(encode_json decode_json);
use v5.36;

has app => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has _subscribed_games => (
    is      => 'ro',
    default => sub { {} },
);

# Primary Redis handle. undef when REDIS_URL is unset or Mojo::Redis unavailable.
has _redis => (
    is      => 'ro',
    lazy    => 1,
    default => sub ($self) {
        my $url = $ENV{REDIS_URL} or return undef;
        my $redis = eval {
            require Mojo::Redis;
            Mojo::Redis->new($url);
        };
        if ($@ || !$redis) {
            $self->app->log->error("Broadcaster: cannot connect to Redis ($url): " . ($@ || 'unknown'));
            return undef;
        }
        $self->app->log->info("Broadcaster: Redis connected at $url");
        return $redis;
    },
);

# PubSub handle derived from _redis. Sets up the global broadcast listener on first access.
has _pubsub => (
    is      => 'ro',
    lazy    => 1,
    default => sub ($self) {
        my $redis = $self->_redis or return undef;
        my $ps = $redis->pubsub;

        $ps->listen('logodal:broadcast' => _on_message(sub ($data) {
            $self->_deliver_all_local($data->{msg}, $data->{exclude} // {});
        }));

        $self->app->log->info("Broadcaster: Redis pub/sub active");
        return $ps;
    },
);

# --- Public API ---

sub announce ($self, $msg, $recipients) {
    return unless $recipients && ref $recipients eq 'ARRAY';
    if (my $ps = $self->_pubsub) {
        for my $r (@$recipients) {
            my $pid = ref $r ? $r->id : $r;
            $self->_notify($ps, "logodal:player:$pid", encode_json({ msg => $msg }),
                sub { $self->_send_local_to_pid($pid, $msg) });
        }
    } else {
        for my $r (@$recipients) {
            my $pid = ref $r ? $r->id : $r;
            $self->_send_local_to_pid($pid, $msg);
        }
    }
}

sub announce_all_but ($self, $msg, $exclude_list = []) {
    my %exclude = map { (ref $_ ? $_->id : $_) => 1 } @$exclude_list;
    if (my $ps = $self->_pubsub) {
        $self->_notify($ps, 'logodal:broadcast', encode_json({ msg => $msg, exclude => \%exclude }),
            sub { $self->_deliver_all_local($msg, \%exclude) });
    } else {
        $self->_deliver_all_local($msg, \%exclude);
    }
}

sub announce_to_game ($self, $msg, $game_id, $exclude_list = []) {
    my %exclude = map { (ref $_ ? $_->id : $_) => 1 } @$exclude_list;
    if (my $ps = $self->_pubsub) {
        $self->_notify($ps, "logodal:game:$game_id", encode_json({ msg => $msg, exclude => \%exclude }),
            sub { $self->_deliver_game_local($game_id, $msg, \%exclude) });
    } else {
        $self->_deliver_game_local($game_id, $msg, \%exclude);
    }
}

# --- Game membership (Redis set, used for cross-replica all_played count) ---

sub add_member ($self, $gid, $pid) {
    my $redis = $self->_redis or return;
    my $ttl   = ($ENV{GAME_DURATION} || 30) + 120;
    eval {
        $redis->db->sadd_p("logodal:members:$gid", $pid)->then(sub {
            eval { $redis->db->expire_p("logodal:members:$gid", $ttl)->catch(sub { }) };
        })->catch(sub { });
    };
}

sub remove_member ($self, $gid, $pid) {
    my $redis = $self->_redis or return;
    eval { $redis->db->srem_p("logodal:members:$gid", $pid)->catch(sub { }) };
}

# Calls $cb->($count) — async when Redis available, sync with $fallback otherwise.
sub get_member_count ($self, $gid, $fallback, $cb) {
    my $redis = $self->_redis or return $cb->($fallback);
    eval {
        $redis->db->scard_p("logodal:members:$gid")->then(sub {
            $cb->($_[0] || $fallback);
        })->catch(sub { $cb->($fallback) });
    } or $cb->($fallback);
}

# --- Chat history (Redis list, falls back to caller-supplied local history) ---

sub store_chat ($self, $game_id, $msg) {
    my $redis = $self->_redis or return;
    my $key   = "logodal:chat:$game_id";
    my $limit = $ENV{CHAT_HISTORY_SIZE} || 50;
    eval {
        $redis->db->rpush_p($key, encode_json($msg))->then(sub {
            eval { $redis->db->ltrim_p($key, -$limit, -1)->catch(sub { }) };
        })->catch(sub { });
    };
}

# Calls $cb->(\@messages) — async when Redis available, sync otherwise.
sub get_chat_history ($self, $game_id, $fallback, $cb) {
    my $redis = $self->_redis or return $cb->($fallback);
    eval {
        $redis->db->lrange_p("logodal:chat:$game_id", 0, -1)->then(sub {
            my @msgs = grep { defined } map { eval { decode_json($_) } } @{$_[0]};
            $cb->(\@msgs);
        })->catch(sub { $cb->($fallback) });
    } or $cb->($fallback);
}

# --- Subscription lifecycle (no-ops when Redis is not configured) ---

sub subscribe_player ($self, $pid) {
    my $ps = $self->_pubsub or return;
    $ps->listen("logodal:player:$pid" => _on_message(sub ($data) {
        $self->_send_local_to_pid($pid, $data->{msg});
    }));
}

sub unsubscribe_player ($self, $pid) {
    my $ps = $self->_pubsub or return;
    $ps->unlisten("logodal:player:$pid");
}

sub subscribe_game ($self, $gid) {
    my $ps = $self->_pubsub or return;
    return if $self->_subscribed_games->{$gid};
    $self->_subscribed_games->{$gid} = 1;
    $ps->listen("logodal:game:$gid" => _on_message(sub ($data) {
        $self->_deliver_game_local($gid, $data->{msg}, $data->{exclude} // {});
    }));
}

sub unsubscribe_game ($self, $gid) {
    my $ps = $self->_pubsub or return;
    return unless delete $self->_subscribed_games->{$gid};
    $ps->unlisten("logodal:game:$gid");
}

# --- Internal helpers ---

# Wraps a handler as a Mojo::Redis::PubSub listen callback. Mojo::Redis calls
# it as $pubsub->$cb($payload, $channel); a two-argument signature dies on
# every message, silently dropping all cross-instance delivery. Payloads that
# aren't JSON are ignored.
sub _on_message ($handler) {
    return sub ($pubsub, $payload, $channel = undef) {
        my $data = eval { decode_json($payload) } or return;
        $handler->($data);
    };
}

# notify returns undef when Redis is already dead, or a rejected promise when it dies mid-flight.
# Either way, run $fallback.
sub _notify ($self, $ps, $channel, $payload, $fallback) {
    my $p = eval { $ps->notify($channel, $payload) };
    if ($@ || !defined $p) {
        $fallback->();
    } else {
        $p->catch($fallback);
    }
}

# --- Local delivery helpers (used as fallback and from Redis callbacks) ---

sub _deliver_game_local ($self, $gid, $msg, $exclude) {
    my $clients = $self->app->games->{$gid}{clients} // {};
    my $type    = $msg->{type} // 'unknown';
    for my $pid (keys %$clients) {
        next if $exclude->{$pid};
        my $c = $clients->{$pid};
        if ($c && $c->tx) {
            $self->app->log->debug("Broadcaster[Game $gid]: Sending type '$type' to player $pid");
            $c->send({json => $msg});
        }
    }
}

sub _deliver_all_local ($self, $msg, $exclude) {
    for my $gid (keys %{$self->app->games}) {
        $self->_deliver_game_local($gid, $msg, $exclude);
    }
}

sub _send_local_to_pid ($self, $pid, $msg) {
    my $type = $msg->{type} // 'unknown';
    for my $gid (keys %{$self->app->games}) {
        my $c = $self->app->games->{$gid}{clients}{$pid};
        if ($c && $c->tx) {
            $self->app->log->debug("Broadcaster[Game $gid]: Sending type '$type' to player $pid");
            $c->send({json => $msg});
            return;
        }
    }
}

1;
