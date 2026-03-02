package Wordwank::Service::Wordd;
use Mojo::Base -base, -signatures;
use Mojo::URL;

has 'app';
has 'host' => sub { $ENV{WORDD_HOST} || 'wordd' };
has 'port' => sub { $ENV{WORDD_PORT} || 2345 };

sub validate ($self, $word, $lang, $cb) {
    my $url = Mojo::URL->new("http://" . $self->host . ":" . $self->port . "/validate/$lang/")->path(lc($word));
    $self->app->ua->get($url => sub ($ua, $tx) { $cb->($tx->res) });
}

sub define ($self, $word, $lang, $cb) {
    my $url = "http://" . $self->host . ":" . $self->port . "/define/$lang/" . lc($word);
    $self->app->ua->get($url => sub ($ua, $tx) { $cb->($tx->res) });
}

sub suggest ($self, $letters, $lang, $cb) {
    my $url = "http://" . $self->host . ":" . $self->port . "/rand/langs/$lang/word?letters=" . lc($letters) . "&count=1";
    $self->app->ua->get($url => sub ($ua, $tx) { $cb->($tx->res) });
}

1;
