use Test::More;
use Mojo::Base -signatures;
use Wordwank::Game::Broadcaster;

# Mock App
package MockApp {
    use Mojo::Base -base;
    has games => sub { {} };
}

# Mock Client
package MockClient {
    use Mojo::Base -base;
    has 'tx' => 1;
    has 'sent' => sub { [] };
    sub send ($self, $msg) {
        push @{$self->sent}, $msg;
    }
}

my $app = MockApp->new;
my $broadcaster = Wordwank::Game::Broadcaster->new(app => $app);

# Setup a game with some clients
my $gid = 'game-1';
my $c1 = MockClient->new;
my $c2 = MockClient->new;
my $c3 = MockClient->new;

$app->games->{$gid} = {
    clients => {
        'p1' => $c1,
        'p2' => $c2,
        'p3' => $c3,
    }
};

subtest 'announce to specific pids' => sub {
    $broadcaster->announce({type => 'test'}, ['p1', 'p2']);
    is(scalar @{$c1->sent}, 1, 'p1 received message');
    is(scalar @{$c2->sent}, 1, 'p2 received message');
    is(scalar @{$c3->sent}, 0, 'p3 received nothing');
    
    is($c1->sent->[0]{json}{type}, 'test', 'correct message content');
};

subtest 'announce_all_but' => sub {
    # Clear sent
    $c1->sent([]); $c2->sent([]); $c3->sent([]);
    
    $broadcaster->announce_all_but({type => 'global'}, ['p2']);
    is(scalar @{$c1->sent}, 1, 'p1 received');
    is(scalar @{$c2->sent}, 0, 'p2 excluded');
    is(scalar @{$c3->sent}, 1, 'p3 received');
};

subtest 'announce_to_game' => sub {
    $c1->sent([]); $c2->sent([]); $c3->sent([]);
    
    $broadcaster->announce_to_game({type => 'game_msg'}, $gid, ['p1']);
    is(scalar @{$c1->sent}, 0, 'p1 excluded from game msg');
    is(scalar @{$c2->sent}, 1, 'p2 received');
    is(scalar @{$c3->sent}, 1, 'p3 received');
};

done_testing();
