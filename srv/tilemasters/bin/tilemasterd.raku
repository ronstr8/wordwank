use Cro::HTTP;
use Tilemasters::Game;
use Tilemasters::Scorer;
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
    post -> "game" {
        my $uuid = ('a'..'z').roll(10).join;
        my @letters = Tilemasters::Scorer.get-random-rack();
        %games{$uuid} = Game.new(:$uuid, rack => @letters);
        return { uuid => $uuid, rack => @letters }.to-json;
    }
    get -> "game" / $<uuid> / "play" / $<word> {
        handle-play($<uuid>, $<word>, request.headers<Authorization>);
    }
    post -> "game" / $<uuid> / "end" {
        end-game($<uuid>);
    }
};

Cro::HTTP::Server.new(:host<0.0.0.0>, :port(3883), :application($app)).run;
