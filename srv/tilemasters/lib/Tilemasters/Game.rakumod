unit module Tilemasters::Game;

use JSON::Fast;
use Tilemasters::Scorer;
use Tilemasters::Validator;
use Tilemasters::Player;

class Game {
    has $.uuid;
    has $.rack is rw;
    has @.plays;
    has $!start-time = now;
    has $.duration = 60; # seconds

    method time-left() {
        max(0, $.duration - (now - $!start-time))
    }

    method play(Str $word, Str $auth-header) {
        my $player = Tilemasters::Player.validate-token($auth-header);
        return { error => "Invalid token" }.to-json unless $player;

        return { error => "Invalid word" }.to-json unless Tilemasters::Validator.validate-word($word);

        my $score = Tilemasters::Scorer.calculate-score($word);
        @.plays.push({ player => $player, word => $word, score => $score });

        return { success => True, score => $score }.to-json;
    }

    method end-game() {
        my %results = Tilemasters::Scorer.calculate-final-scores(@.plays);
        return %results.to-json;
    }
}
