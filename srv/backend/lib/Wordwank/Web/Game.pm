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
    
        # Generate letter values using new scoring rules
        my $vals = $app->scorer->generate_letter_values();
        
        $gid = create_uuid_as_string(UUID_V4);
        $active_game = $game_rs->create({
            id            => $gid,
            rack          => $rack,
            letter_values => $vals,
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
            # Buffer for network latency / last second submissions
            Mojo::IOLoop->timer(2 => sub { $self->_end_game($game) });
        }
    });
}

sub _end_game ($self, $game) {
    my $schema = $self->app->schema;
    my $app = $self->app;
    $game->update({ finished_at => DateTime->now });

    # Fetch all plays for this game with player info
    my @plays = $schema->resultset('Play')->search(
        { game_id => $game->id },
        {
            join     => 'player',
            select   => [ 'me.player_id', 'player.nickname', 'me.word', 'me.score', 'player.language', 'me.created_at' ],
            as       => [ qw/player_id player word score language created_at/ ],
            order_by => { -asc => 'me.created_at' }
        }
    )->all;

    # Track duplicates: word -> [player_ids in order]
    my %word_to_players;
    my %player_bonuses;  # player_id -> { duplicates => count, all_tiles => 10 }
    my %is_duper;  # player_id -> 1 if they duplicated someone
    
    for my $play (@plays) {
        my $word = $play->get_column('word');
        my $player_id = $play->get_column('player_id');
        
        push @{$word_to_players{$word}}, $player_id;
        
        # Initialize bonus tracking for this player
        $player_bonuses{$player_id} //= { duplicates => 0, all_tiles => 0 };
        
        # Check if this play used all tiles
        if ($app->scorer->uses_all_tiles($word, $game->rack)) {
            $player_bonuses{$player_id}{all_tiles} = 10;
        }
    }
    
    # Calculate duplicate bonuses and mark dupers
    for my $word (keys %word_to_players) {
        my $players = $word_to_players{$word};
        if (scalar(@$players) > 1) {
            # First player is the original
            my $original_player = $players->[0];
            my $duplicate_count = scalar(@$players) - 1;
            $player_bonuses{$original_player}{duplicates} += $duplicate_count;
            
            # Mark all subsequent players as dupers
            for my $i (1 .. $#$players) {
                $is_duper{$players->[$i]} = 1;
            }
        }
    }
    
    # Solo player rule: if only one player submitted, everyone gets 0 points
    my $solo_game = scalar(@plays) == 1;
    
    # Build enhanced results with bonuses
    my @results;
    my %player_total_scores;  # Track total scores including bonuses
    
    for my $play (@plays) {
        my $player_id = $play->get_column('player_id');
        my $word = $play->get_column('word');
        my $base_score = $play->get_column('score');
        my $bonuses = $player_bonuses{$player_id};
        
        my $duplicate_bonus = $bonuses->{duplicates} || 0;
        my $all_tiles_bonus = $bonuses->{all_tiles} || 0;
        
        # NEW RULES:
        # 1. If this player is a duper, they get 0 points for their word
        # 2. If solo game (only one player), everyone gets 0
        my $total_score;
        if ($solo_game) {
            $total_score = 0;
        } elsif ($is_duper{$player_id}) {
            # Duper gets 0 for their word, but original still gets +1 bonus
            $total_score = 0;
        } else {
            $total_score = $base_score + $duplicate_bonus + $all_tiles_bonus;
        }
        
        # Track highest score per player (in case of multiple plays, though we prevent this)
        if (!exists $player_total_scores{$player_id} || $total_score > $player_total_scores{$player_id}{score}) {
            $player_total_scores{$player_id} = {
                player_id       => $player_id,
                player          => $play->get_column('player'),  # nickname for display
                word            => $word,
                score           => $total_score,
                base_score      => $is_duper{$player_id} ? 0 : $base_score,
                duplicate_bonus => $duplicate_bonus,
                all_tiles_bonus => $solo_game ? 0 : $all_tiles_bonus,
                is_dupe         => $is_duper{$player_id} ? 1 : 0,
            };
        }
    }
    
    # Convert to sorted array
    @results = sort { $b->{score} <=> $a->{score} } values %player_total_scores;
    
    # Update player cumulative scores in database
    for my $result (@results) {
        my $player = $schema->resultset('Player')->find($result->{player_id});
        if ($player) {
            $player->update({ lifetime_score => ($player->lifetime_score || 0) + $result->{score} });
        }
    }

    my $winner = $results[0];
    my $winner_word = $winner ? $winner->{word} : undef;
    my $winner_lang = $plays[0] ? ($plays[0]->get_column('language') // 'en') : 'en';

    # Build payload with bonus details
    my $payload = [ map { 
        my $item = { 
            player => $_->{player}, 
            word   => $_->{word}, 
            score  => $_->{score},
            is_dupe => $_->{is_dupe},
        };
        # Add bonuses array if any exist
        my @bonuses;
        push @bonuses, { 'Duplicates' => $_->{duplicate_bonus} } if $_->{duplicate_bonus} > 0;
        push @bonuses, { 'All Tiles' => $_->{all_tiles_bonus} } if $_->{all_tiles_bonus} > 0;
        $item->{bonuses} = \@bonuses if @bonuses;
        $item;
    } @results ];

    my $send_results = sub ($definition = undef) {
        $self->app->log->debug("Broadcasting game_end with definition: " . (defined $definition ? length($definition) . " chars" : "NONE"));
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
        my $wordd_url = $ENV{WORDD_URL} || "http://wordd:2345/word/$winner_lang/";
        my $full_url = $wordd_url . lc($winner_word);
        $self->app->log->debug("Fetching winner definition: $full_url");
        $self->app->ua->get($full_url => sub ($ua, $tx) {
            my $res = $tx->result;
            $self->app->log->debug("Wordd response [ " . ($res->code // 'ERR') . " ] Size: " . length($res->body // ''));
            $send_results->($res->body);
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
