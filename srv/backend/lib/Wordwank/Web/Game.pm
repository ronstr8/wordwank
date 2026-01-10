package Wordwank::Web::Game;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util;
use UUID::Tiny qw(:std);
use DateTime;
use Wordwank::Util::NameGenerator;

my $DEFAULT_GAME_DURATION = 30;

sub generate_procedural_name ($id) {
    return Wordwank::Util::NameGenerator->new->generate($id);
}

sub websocket ($self) {
    $self->inactivity_timeout(3600);

    my $player_id = $self->param('id') || 'anon-' . int(rand(1000000));
    my $schema    = $self->app->schema;
    my $app       = $self->app;

    # 1. Identity & Database Setup
    my $player = $schema->resultset('Player')->find_or_create({
        id       => $player_id,
        nickname => generate_procedural_name($player_id),
    });

    # Send identity immediately
    $self->send({json => {
        type    => 'identity',
        payload => { 
            id       => $player->id, 
            name     => $player->nickname,
            language => $player->language
        }
    }});

    # 2. Connection Tracking
    my $client_id = "$self"; # Unique stringified controller
    $app->log->debug("Player $player_id connected via $client_id");

    $self->on(message => sub ($c, $msg) {
        my $data = eval { decode_json($msg) };
        return $c->app->log->error("Invalid JSON: $@") if $@;

        my $type    = $data->{type}    // '';
        my $payload = $data->{payload} // {};

        if ($type eq 'join') {
            $c->_handle_join($player);
        }
        elsif ($type eq 'chat') {
            $c->_handle_chat($player, $payload);
        }
        elsif ($type eq 'play') {
            $c->_handle_play($player, $payload);
        }
        elsif ($type eq 'set_language') {
            $c->_handle_set_language($player, $payload);
        }
    });

    $self->on(finish => sub ($c, $code, $reason) {
        $c->_handle_disconnect($player->id);
    });
}

sub _handle_join ($self, $player) {
    my $app = $self->app;
    # Find active game or start one
    my $game_rs = $self->app->schema->resultset('Game');
    my $active_game = $game_rs->search({ finished_at => undef }, { order_by => { -desc => 'started_at' }, rows => 1 })->single;

    my $gid;
    if (!$active_game) {
        # Create new game
        my $rack = $app->scorer->get_random_rack;
        # Generate random letter values if intended
        my %vals = map { $_ => int(rand(10)) + 1 } ('A'..'Z');
        
        $gid = create_uuid_as_string(UUID_V4);
        $active_game = $game_rs->create({
            id            => $gid,
            rack          => $rack,
            letter_values => \%vals,
            started_at    => DateTime->now,
        });

        # Initialize game state in memory
        $app->games->{$gid} = { 
            clients   => {}, 
            state     => $active_game,
            time_left => $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION,
        };

        # Start a server-side timer for this game
        $self->_start_game_timer($active_game);
    }
    else {
        $gid = $active_game->id;
        # Zombie Recovery: If game is in DB but not in memory
        if (!$app->games->{$gid}) {
            my $elapsed = time - $active_game->started_at->epoch;
            my $time_left = ($ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION) - $elapsed;
            
            if ($time_left > 0) {
                $app->games->{$gid} = {
                    clients   => {},
                    state     => $active_game,
                    time_left => $time_left,
                };
                $self->_start_game_timer($active_game);
            }
            else {
                # This game should have ended. End it now and rotate.
                $self->_end_game($active_game);
                # Return early as _end_game will trigger a new join via timer
                return;
            }
        }
    }

    # Store client in app state
    $app->games->{$gid}{clients}{$player->id} = $self;

    # Send game_start with accurate time_left
    $self->send({json => {
        type    => 'game_start',
        payload => {
            uuid          => $gid,
            rack          => $active_game->rack,
            letter_values => $active_game->letter_values,
            time_left     => $app->games->{$gid}{time_left},
        }
    }});
}

sub _handle_chat ($self, $player, $payload) {
    my $text = ref $payload eq 'HASH' ? $payload->{text} : $payload;
    $self->_broadcast_to_player_game($player->id, {
        type    => 'chat',
        sender  => $player->id,
        payload => {
            text       => $text,
            senderName => $player->nickname,
        }
    });
}

sub _handle_play ($self, $player, $payload) {
    my $word = uc($payload->{word} // '');
    my $game_data = $self->_get_player_game($player->id);
    return unless $game_data;

    my $game_record = $game_data->{state};
    my $app = $self->app;
    $app->log->debug("Player " . $player->id . " attempted word: $word");

    # Prevent double submissions
    my $existing = $app->schema->resultset('Play')->find({
        game_id   => $game_record->id,
        player_id => $player->id,
    });
    if ($existing) {
        $app->log->debug("Player " . $player->id . " already submitted");
        return;
    }

    # Verify word can be formed from rack
    my $rack = $game_record->rack;
    $app->log->debug("Checking word '$word' against player rack: @$rack");
    unless ($app->scorer->can_form_word($word, $rack)) {
        $app->log->debug("Word '$word' FAILED rack check");
        return $self->send({json => {
            type    => 'error',
            payload => "Nice try, but those letters aren't on your rack. Wanker."
        }});
    }

    # Non-blocking validation via wordd
    # Use internal Kubernetes service name
    my $lang = $player->language // 'en';
    my $wordd_url = $ENV{WORDD_URL} || "http://wordd:2345/validate/$lang/";
    
    $app->log->debug("Requesting validation from wordd: $wordd_url" . lc($word));
    $app->ua->get($wordd_url . lc($word) => sub ($ua, $tx) {
        my $res = $tx->result;
        if ($res->is_success) {
            $app->log->debug("Word '$word' VALIDATED by wordd");
            # Word is valid!
            my $score = $app->scorer->calculate_score($word, $game_record->letter_values);

            # Persist the play
            my $play = $app->schema->resultset('Play')->create({
                game_id   => $game_record->id,
                player_id => $player->id,
                word      => $word,
                score     => $score,
            });

            $self->_broadcast_to_player_game($player->id, {
                type      => 'play',
                sender    => $player->id,
                timestamp => time,
                payload   => {
                    word       => $word,
                    score      => $score,
                    playerName => $player->nickname,
                }
            });
        }
        else {
            $app->log->debug("Word '$word' REJECTED by wordd. Status: " . ($res->code // 'unknown'));
            # Word is invalid or wordd is down
            $self->send({json => {
                type    => 'error',
                payload => "The word '$word' is not in our dictionary of wank."
            }});
        }
    });
}

sub _start_game_timer ($self, $game) {
    my $app = $self->app;
    my $gid = $game->id;

    my $timer_id;
    $timer_id = Mojo::IOLoop->recurring(1 => sub ($loop) {
        my $g = $app->games->{$gid};
        if (!$g) {
            $loop->remove($timer_id);
            return;
        }

        $g->{time_left}--;
        
        # Broadcast timer update (clamped to 0)
        $self->_broadcast_to_game($gid, {
            type    => 'timer',
            payload => { time_left => ($g->{time_left} > 0 ? $g->{time_left} : 0) }
        });

        if ($g->{time_left} <= 0) {
            $loop->remove($timer_id);
            $self->_end_game($game);
        }
    });
}

sub _end_game ($self, $game) {
    my $schema = $self->app->schema;
    $game->update({ finished_at => DateTime->now });

    # Calculate final results
    my @results = $schema->resultset('Play')->search(
        { game_id => $game->id },
        {
            join     => 'player',
            select   => [ 'player.nickname', 'me.word', 'me.score' ],
            as       => [ qw/player word score/ ],
            order_by => { -desc => 'score' }
        }
    )->all;

    my $payload = [ map { { 
        player => $_->get_column('player'), 
        word   => $_->get_column('word'), 
        score  => $_->get_column('score') 
    } } @results ];

    my $winner_word = $results[0] ? $results[0]->get_column('word') : undef;

    my $send_results = sub ($definition = undef) {
        $self->_broadcast_to_game($game->id, {
            type    => 'game_end',
            payload => {
                plays      => $payload,
                definition => $definition,
            }
        });

        # Store clients to re-join them later
        my $clients = $self->app->games->{$game->id}{clients};

        # Cleanup memory
        delete $self->app->games->{$game->id};

        # Rotate to a new game after a short results period (5s)
        Mojo::IOLoop->timer(5 => sub {
            # Trigger handle_join for all previously connected clients
            for my $pid (keys %$clients) {
                my $c = $clients->{$pid};
                # Check if controller still exists/connected
                if ($c && $c->tx) {
                    $c->_handle_join($schema->resultset('Player')->find($pid));
                }
            }
        });
    };

    if ($winner_word) {
        my $wordd_url = $ENV{WORDD_URL} || "http://wordd:2345/word/en/";
        $self->app->ua->get($wordd_url . lc($winner_word) => sub ($ua, $tx) {
            $send_results->($tx->result->body);
        });
    } else {
        $send_results->();
    }
}

sub _handle_set_language ($self, $player, $payload) {
    my $lang = $payload->{language} // 'en';
    $player->update({ language => $lang });
    $self->app->log->debug("Player " . $player->id . " set language to $lang");
}

# --- Utilities ---

sub _broadcast_to_game ($self, $game_id, $msg) {
    my $game_clients = $self->app->games->{$game_id}{clients} // {};
    for my $pid (keys %$game_clients) {
        my $c = $game_clients->{$pid};
        if ($c && $c->tx) {
            $c->send({json => $msg});
        }
    }
}

sub _broadcast_to_player_game ($self, $player_id, $msg) {
    my $gid;
    for my $game (keys %{$self->app->games}) {
        if (exists $self->app->games->{$game}{clients}{$player_id}) {
            $gid = $game;
            last;
        }
    }
    $self->_broadcast_to_game($gid, $msg) if $gid;
}

sub _get_player_game ($self, $player_id) {
    for my $game (values %{$self->app->games}) {
        return $game if exists $game->{clients}{$player_id};
    }
    return undef;
}

sub _handle_disconnect ($self, $player_id) {
    for my $game (values %{$self->app->games}) {
        delete $game->{clients}{$player_id};
    }
}

1;
