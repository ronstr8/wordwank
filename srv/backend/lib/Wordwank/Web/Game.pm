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
    my $lang = $player->language // 'en';
    $app->log->debug("Player " . $player->id . " ($lang) attempting to join...");
    
    # 1. Search for active (started) game for this player's language
    my $game_rs = $self->app->schema->resultset('Game');
    my $active_game = $game_rs->search(
        { 
            finished_at => undef, 
            language    => $lang,
            started_at  => { -not => undef }
        }, 
        { order_by => { -desc => 'started_at' }, rows => 1 }
    )->single;

    # Check for stale games (Zombie Recovery for started games)
    if ($active_game) {
        my $gid = $active_game->id;
        my $elapsed = time - $active_game->started_at->epoch;
        my $total_dur = $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION;
        
        $app->log->debug("Found active game $gid ($elapsed/$total_dur)");

        if ($elapsed >= $total_dur) {
            $app->log->debug("Found stale game $gid, rotating...");
            $self->_end_game($active_game);
            $active_game = undef; # Force check for pending or new game
        }
    }

    my $gid;
    # 2. If no active (started) game, look for a pending game (started_at is NULL)
    if (!$active_game) {
        $app->log->debug("No active game for $lang, searching for pending...");
        $active_game = $game_rs->search(
            { 
                finished_at => undef, 
                language    => $lang,
                started_at  => undef 
            }, 
            { order_by => { -asc => 'created_at' }, rows => 1 }
        )->single;

        if ($active_game) {
            # Start this pending game!
            $gid = $active_game->id;
            $app->log->debug("Starting pending $lang game $gid");
            $active_game->update({ started_at => DateTime->now });
            
            # Initialize in-memory state
            $app->games->{$gid} = {
                clients   => {},
                state     => $active_game,
                time_left => $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION,
            };
            $self->_start_game_timer($active_game);
        }
        else {
            # Fallback (should be rare with background task): Create and start immediately
            $app->log->debug("No pending game found, creating emergency $lang game");
            my $rack = $app->scorer->get_random_rack($lang);
            my $vals = $app->scorer->generate_letter_values($lang);
            
            $gid = create_uuid_as_string(UUID_V4);
            $active_game = $game_rs->create({
                id            => $gid,
                rack          => $rack,
                letter_values => $vals,
                language      => $lang,
                started_at    => DateTime->now,
            });

            $app->games->{$gid} = { 
                clients   => {}, 
                state     => $active_game,
                time_left => $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION,
            };
            $self->_start_game_timer($active_game);
        }
    }
    else {
        # Active game found, ensure it's in memory
        $gid = $active_game->id;
        $app->log->debug("Joining existing game $gid");
        if (!$app->games->{$gid}) {
             # Zombie Recovery: Restart timer if missing from memory
             my $elapsed = time - $active_game->started_at->epoch;
             my $total_dur = $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION;
             $app->log->debug("Recovering zombie game $gid to memory ($elapsed/$total_dur)");
             $app->games->{$gid} = {
                 clients   => {},
                 state     => $active_game,
                 time_left => $total_dur - $elapsed,
             };
             $self->_start_game_timer($active_game);
        }
    }

    # Store client in app state
    $app->games->{$gid}{clients}{$player->id} = $self;
    
    # Send game_start with accurate time_left and language-specific configs
    my $game_lang = $active_game->language // 'en';
    $app->log->debug("Broadcasting game_start for $gid");
    $self->send({json => {
        type    => 'game_start',
        payload => {
            uuid          => $gid,
            rack          => $active_game->rack,
            letter_values => $active_game->letter_values,
            tile_counts   => $app->scorer->tile_counts($game_lang),
            unicorns      => $app->scorer->unicorns($game_lang),
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
    my $word  = $payload->{word} // '';
    my $game_data = $self->_get_player_game($player->id);
    return unless $game_data;

    my $game_record = $game_data->{state};
    my $app = $self->app;
    $app->log->debug("Player " . $player->id . " attempted: $word");

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
    # Use the game's language for consistency
    my $lang = $game_record->language // 'en';
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
            $app->log->debug("Recorded play for player " . $player->id . " in game " . $game_record->id . ": $word ($score pts)");
            $self->_broadcast_to_player_game($player->id, {
                type      => 'play',
                sender    => $player->id,
                timestamp => time,
                payload   => {
                    word       => $word,
                    score      => $score,
                    playerName => $player->nickname,
                    msg        => "You played $word for $score pts!",
                }
            });
        }
        else {
            $app->log->debug("Word '$word' REJECTED by wordd. Status: " . ($res->code // 'unknown'));
            # Word is invalid or wordd is down
            $self->send({json => {
                type    => 'error',
                payload => "The word '$word' is not amongst our wanking lexicon."
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

    my @plays = $schema->resultset('Play')->search(
        { game_id => $game->id },
        {
            join     => 'player',
            select   => [ 'me.player_id', 'player.nickname', 'me.word', 'me.score', 'player.language', 'me.created_at' ],
            as       => [ qw/player_id player word score language created_at/ ],
            order_by => { -asc => 'me.created_at' }
        }
    )->all;

    my $found_plays = scalar(@plays);
    $app->log->debug("Ending game " . $game->id . " - Found $found_plays plays");

    my %word_to_players;
    my %player_bonuses;  # player_id -> { duplicates => count, length_bonus => count, unique => count, duped_by => [ { name => nickname, bonus => 1 } ] }
    my %is_duper;  # player_id -> 1 if they duplicated someone
    my %player_id_to_nickname;
    
    for my $play (@plays) {
        my $word = $play->get_column('word');
        my $player_id = $play->get_column('player_id');
        
        push @{$word_to_players{$word}}, $player_id;
        $player_id_to_nickname{$player_id} = $play->get_column('player');
        
        # Initialize bonus tracking for this player
        $player_bonuses{$player_id} //= { duplicates => 0, unique => 0, length_bonus => 0, duped_by => [] };
        
        # Calculate length bonus
        my $bonus = $app->scorer->get_length_bonus($word);
        if ($bonus > 0) {
            $player_bonuses{$player_id}{length_bonus} = $bonus;
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
                my $duper_id = $players->[$i];
                $is_duper{$duper_id} = 1;
                push @{$player_bonuses{$original_player}{duped_by}}, {
                    name  => $player_id_to_nickname{$duper_id},
                    bonus => 1,
                };
            }
        } else {
            # Unique word bonus (+5)
            my $player_id = $players->[0];
            $player_bonuses{$player_id}{unique} = 5;
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
        my $unique_bonus = $bonuses->{unique} || 0;
        my $length_bonus = $bonuses->{length_bonus} || 0;
        
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
            $total_score = $base_score + $duplicate_bonus + $unique_bonus + $length_bonus;
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
                unique_bonus    => $solo_game ? 0 : $unique_bonus,
                length_bonus    => $solo_game ? 0 : $length_bonus,
                duped_by        => $bonuses->{duped_by} // [],
                is_dupe         => $is_duper{$player_id} ? 1 : 0,
            };
        }
    }
    
    # Convert to sorted array
    @results = sort { $b->{score} <=> $a->{score} } values %player_total_scores;
    
    # Update player cumulative scores in database (skip for solo games)
    unless ($solo_game) {
        for my $result (@results) {
            my$player = $schema->resultset('Player')->find($result->{player_id});
            if ($player) {
                $player->update({ lifetime_score => ($player->lifetime_score || 0) + $result->{score} });
            }
        }
    }

    my $winner = $results[0];
    my $winner_word = $winner ? $winner->{word} : undef;
    my $winner_lang = $game->language // 'en';

    # Build payload with bonus details
    my $results_payload = [ map { 
        my $item = { 
            player => $_->{player}, 
            word   => $_->{word}, 
            score  => $_->{score},
            base_score => $_->{base_score},
            is_dupe => $_->{is_dupe},
            duped_by => $_->{duped_by},
        };
        # Add bonuses array if any exist
        my @bonuses;
        push @bonuses, { 'Duplicates' => $_->{duplicate_bonus} } if $_->{duplicate_bonus} > 0;
        push @bonuses, { 'Unique Word' => $_->{unique_bonus} } if $_->{unique_bonus} > 0;
        push @bonuses, { 'Length Bonus' => $_->{length_bonus} } if $_->{length_bonus} > 0;
        $item->{bonuses} = \@bonuses if @bonuses;
        $item;
    } @results ];

    my $send_results = sub ($definition = undef) {
        $self->app->log->debug("Broadcasting game_end with definition: " . (defined $definition ? length($definition) . " chars" : "NONE"));
        $self->_broadcast_to_game($game->id, {
            type      => 'game_end',
            timestamp => time,
            payload   => {
                results => $results_payload,
                is_solo => $solo_game,
                summary => $winner ? sprintf($self->t('results.winner_summary', $winner_lang), $winner->{player}, $winner->{score}, $winner->{word}) : $self->t('results.no_winner', $winner_lang),
                definition => $definition,
            }
        });
        # Cleanup memory
        delete $self->app->games->{$game->id};

        # Note: Players must manually click "Play Again" to join the next game
        # No auto-restart timer
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
