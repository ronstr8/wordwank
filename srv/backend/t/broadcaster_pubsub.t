use Test::More;
use Mojo::Base -signatures;
use Mojo::JSON qw(encode_json);
use Logodal::Game::Broadcaster;

# Messages arriving from Redis must reach the local players. Mojo::Redis calls
# each listen callback as $pubsub->$cb($payload, $channel), three arguments;
# callbacks with a two-argument signature die on every message.

package MockApp {
    use Mojo::Base -base;
    use Mojo::Log;
    has games => sub { {} };
    has log   => sub { Mojo::Log->new(level => 'fatal') };
}

package MockClient {
    use Mojo::Base -base;
    has tx   => 1;
    has sent => sub { [] };
    sub send ($self, $msg) { push @{$self->sent}, $msg }
}

# Stands in for Mojo::Redis::PubSub: keeps the listeners and delivers the way
# the real one does (Mojo/Redis/PubSub.pm, _handle_message).
package FakePubSub {
    use Mojo::Base -base;
    has listeners => sub { {} };
    sub listen ($self, $channel, $cb) { push @{$self->listeners->{$channel}}, $cb; $cb }
    sub unlisten ($self, $channel, @) { delete $self->listeners->{$channel} }
    sub deliver ($self, $channel, $payload) {
        $self->$_($payload, $channel) for @{$self->listeners->{$channel} // []};
    }
}

package FakeRedis {
    use Mojo::Base -base;
    has pubsub => sub { FakePubSub->new };
}

package main;

my $app   = MockApp->new;
my $redis = FakeRedis->new;
my $b     = Logodal::Game::Broadcaster->new(app => $app, _redis => $redis);
my $ps    = $redis->pubsub;

my ($c1, $c2) = (MockClient->new, MockClient->new);
$app->games->{g1} = { clients => { p1 => $c1, p2 => $c2 } };

sub reset_sent { $_->sent([]) for $c1, $c2 }
sub types ($c) { [map { $_->{json}{type} } @{$c->sent}] }

subtest 'player channel delivers to that player' => sub {
    reset_sent();
    $b->subscribe_player('p1');
    $ps->deliver('logodal:player:p1', encode_json({ msg => { type => 'hello' } }));
    is_deeply(types($c1), ['hello'], 'p1 got the message');
    is_deeply(types($c2), [], 'p2 got nothing');
};

subtest 'game channel delivers to the table, honouring exclusions' => sub {
    reset_sent();
    $b->subscribe_game('g1');
    $ps->deliver('logodal:game:g1', encode_json({ msg => { type => 'tick' }, exclude => { p2 => 1 } }));
    is_deeply(types($c1), ['tick'], 'p1 got the message');
    is_deeply(types($c2), [], 'excluded p2 got nothing');
};

subtest 'broadcast channel delivers to everyone not excluded' => sub {
    reset_sent();
    $b->_pubsub;    # first use sets up the broadcast listener
    $ps->deliver('logodal:broadcast', encode_json({ msg => { type => 'news' }, exclude => { p1 => 1 } }));
    is_deeply(types($c1), [], 'excluded p1 got nothing');
    is_deeply(types($c2), ['news'], 'p2 got the message');
};

subtest 'malformed payload is ignored' => sub {
    reset_sent();
    $ps->deliver('logodal:player:p1', 'not json');
    is_deeply(types($c1), [], 'nothing delivered, nothing died');
};

done_testing();
