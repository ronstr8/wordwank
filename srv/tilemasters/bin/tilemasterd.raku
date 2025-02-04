use Cro::HTTP;
use Tilemasters::Game;
use JSON::Fast;

my %games;

sub handle-play($uuid, $word, $auth-header) {
    unless %games{$uuid} {
        return { error => "Game not found" }.to-json;
    }
    return %games{$uuid}.play($word, $auth-header);
}

sub end-game($uuid) {
    unless %games{$uuid} {
        return { error => "Game not found" }.to-json;
    }
    return %games{$uuid}.end-game();
}

my $app = route {
    get -> "game" / $<uuid> / "play" / $<word> {
        handle-play($<uuid>, $<word>, request.headers<Authorization>);
    }
    post -> "game" / $<uuid> / "end" {
        end-game($<uuid>);
    }
};

Cro::HTTP::Server.new(:host<0.0.0.0>, :port(3883), :application($app)).run;
