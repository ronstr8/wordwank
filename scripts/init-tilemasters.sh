#!/bin/bash

BASE_DIR="srv/tilemasters"

# Create necessary directories
mkdir -p $BASE_DIR/{bin,lib/Tilemasters,resources,tests,helm}

# Create main server script
cat << 'EOF' > $BASE_DIR/bin/tilemasterd.raku
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
EOF

# Create Game module
cat << 'EOF' > $BASE_DIR/lib/Tilemasters/Game.rakumod
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
EOF

# Create Scorer module
cat << 'EOF' > $BASE_DIR/lib/Tilemasters/Scorer.rakumod
unit module Tilemasters::Scorer;

class Scorer {
    my %letter-values = (
        A => 1, B => 3, C => 3, D => 2, E => 1, F => 4, G => 2, H => 4, I => 1, J => 8, K => 5, L => 1,
        M => 3, N => 1, O => 1, P => 3, Q => 10, R => 1, S => 1, T => 1, U => 2, V => 4, W => 4, X => 8,
        Y => 4, Z => 10
    );

    method calculate-score(Str $word) {
        [+] $word.comb.map({ %letter-values{$_} // 0 });
    }

    method calculate-final-scores(@plays) {
        my %seen;
        my %original-scorers;
        my $dupe-count = 0;
        my @results;

        for @plays -> $play {
            my %entry = (player => $play<player>, word => $play<word>, score => $play<score>, exceptions => []);

            if %seen{$play<word>} {
                %original-scorers{%seen{$play<word>}} += 1;
                $dupe-count += 1;
                %entry<score> = 0;
            } else {
                %seen{$play<word>} = $play<player>;
            }

            if $play<word>.chars == 7 {
                %entry<exceptions>.push("Used all tiles!" => 10);
                %entry<score> += 10;
            }

            @results.push(%entry);
        }

        for %original-scorers.keys -> $player {
            for @results -> %entry {
                if %entry<player> eq $player {
                    %entry<score> += %original-scorers{$player};
                }
            }
        }

        my @unique-words = @results.grep({ $_<score> > 0 }).map({ $_<word> });
        if @unique-words.elems == 1 {
            my $sole-word = @unique-words[0];
            for @results -> %entry {
                if %entry<word> eq $sole-word {
                    %entry<exceptions>.push("Sole unique word" => $dupe-count);
                    %entry<score> += $dupe-count;
                }
            }
        }

        @results .= sort({ -$_<score> });
        return @results;
    }
}
EOF

# Create Validator module
cat << 'EOF' > $BASE_DIR/lib/Tilemasters/Validator.rakumod
unit module Tilemasters::Validator;

use Cro::HTTP;

class Validator {
    method validate-word(Str $word) {
        my $response = await Cro::HTTP::Client.get("http://wordd/validate/$word");
        return $response.code == 200;
    }
}
EOF

# Create Player module
cat << 'EOF' > $BASE_DIR/lib/Tilemasters/Player.rakumod
unit module Tilemasters::Player;

class Player {
    method validate-token(Str $auth-header) {
        # Stub for OAuth validation (to be implemented)
        return $auth-header ?? 'player-123' !! Nil;
    }
}
EOF

# Create Helm chart
cat << 'EOF' > $BASE_DIR/helm/Chart.yaml
apiVersion: v2
name: tilemasterd
description: A Raku-based microservice for Wordwank Tilemasters
type: application
version: 0.1.0
EOF

# Create Helm values.yaml
cat << 'EOF' > $BASE_DIR/helm/values.yaml
replicaCount: 1

image:
  repository: ghcr.io/ronstr8/tilemasterd
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 3883

resources: {}
EOF

# Create README
cat << 'EOF' > $BASE_DIR/README.md
# Tilemasterd - A Wordwank Microservice

This is the Tilemaster microservice for Wordwank, implemented in Raku.

## Features
- Provides an HTTP API for handling word plays
- Calculates scores based on Scrabble-like rules
- Tracks player performance and game status

## Running Locally
```sh
raku bin/tilemasterd.raku
EOF
