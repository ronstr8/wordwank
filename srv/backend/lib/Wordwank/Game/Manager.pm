package Wordwank::Game::Manager;
use Mojo::Base -base, -signatures;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Util;
use Mojo::IOLoop;
use DateTime;

has 'app';

my $DEFAULT_GAME_DURATION = $ENV{GAME_DURATION} || 30;
my $DEFAULT_LANG = $ENV{DEFAULT_LANG} || 'en';
my $DEFAULT_RACK_SIZE = $ENV{RACK_SIZE} || 8;

sub join_player ($self, $controller, $player, $payload = undef) {
    my $app = $self->app;
    my $schema = $app->schema;

    # Update player info from payload if provided
    if (ref $payload eq 'HASH') {
        my %update;
        $update{nickname} = $payload->{nickname} if $payload->{nickname};
        $update{language} = $payload->{language} if $payload->{language};
        $player->update(\%update) if %update;
    }

    my $invite_gid = ref $payload eq 'HASH' ? $payload->{gid} : undef;
    my $lang = $player->language // $DEFAULT_LANG;
    $app->log->debug("Player " . $player->id . " ($lang) attempting to join..." . ($invite_gid ? " (invited to $invite_gid)" : ""));
    
    my $registry_res = $app->game_registry->get_or_create_game($player, $invite_gid);
    my $action = $registry_res->{action};
    my $active_game = $registry_res->{game};

    if ($action eq 'end_and_retry') {
        $self->end_game($active_game);
        return $self->join_player($controller, $player); # Retry
    }
    elsif ($action eq 'retry') {
        return $self->join_player($controller, $player); # Retry
    }
    elsif ($action eq 'start_timer') {
        $self->start_game_timer($active_game);
    }

    my $gid = $active_game->id;
    $app->log->debug("Joining game $gid (Action: $action)");

    # Store client in app state
    $app->games->{$gid}{clients}{$player->id} = $controller;
    
    # Get list of other players in this game
    my @other_nicknames;
    my $game_clients = $app->games->{$gid}{clients} // {};
    for my $pid (keys %$game_clients) {
        next if $pid eq $player->id;
        my $p = $schema->resultset('Player')->find($pid);
        push @other_nicknames, $p->nickname if $p;
    }

    # Send game_start with accurate time_left and language-specific configs
    my $game_lang = $active_game->language // $DEFAULT_LANG;
    $app->log->debug("Broadcasting game_start for $gid");
    $controller->send({json => {
        type    => 'game_start',
        payload => {
            uuid          => $gid,
            rack          => $active_game->rack,
            rack_size     => (ref($active_game->rack) eq 'ARRAY' ? scalar(@{$active_game->rack}) : 0),
            tile_values   => $active_game->letter_values,
            tile_counts   => $app->scorer->tile_counts($game_lang),
            unicorns      => $app->scorer->unicorns($game_lang),
            time_left     => $app->games->{$gid}{time_left},
            players       => [ @other_nicknames, map { $_->nickname } @{$app->games->{$gid}{ais} // []} ],
        }
    }});

    if (!$active_game->letter_values) {
        $app->log->error("Game " . $active_game->id . " has NO letter_values in database!");
    }

    # If this is the first player joining a game, notify admin
    if (scalar(keys %$game_clients) == 1) {
        my $full_lang = $controller->t("app.lang_$game_lang", $game_lang);
        $app->notify_admin($controller->t('app.invite_notify', $game_lang, { 
            name => $player->nickname, 
            lang => $full_lang,
            url  => 'https://wordwank.fazigu.org' 
        }));
    }

    # Notify others of the join
    for my $pid (keys %$game_clients) {
        next if $pid eq $player->id;
        unless ($self->_have_encountered($player->id, $pid)) {
            my $c = $game_clients->{$pid};
            if ($c && $c->tx) {
                $c->send({json => {
                    type    => 'player_joined',
                    payload => {
                        id   => $player->id,
                        name => $player->nickname
                    }
                }});
            }
        }
    }

    # Also broadcast identity
    $app->broadcaster->announce_to_game({
        type    => 'identity',
        payload => { 
            id   => $player->id, 
            name => $player->nickname
        }
    }, $gid, [$player->id]);

    # Send chat history to the new player
    $controller->send({json => {
        type    => 'chat_history',
        payload => $app->chat_history
    }});
}

sub handle_chat ($self, $controller, $player, $payload) {
    my $text = ref $payload eq 'HASH' ? $payload->{text} : $payload;
    # Isolate chat to the current game
    my $game_data = $self->_get_player_game($player->id);
    if ($game_data) {
        $controller->broadcast_to_game({
            type    => 'chat',
            sender  => $player->id,
            payload => {
                text       => $text,
                senderName => $player->nickname,
            }
        }, $game_data->{state}->id);
    }
}

sub handle_play ($self, $controller, $player, $payload) {
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

    eval {
        $self->_perform_play($controller, $player, $payload, $word, $game_data, $game_record);
    };
    if ($@) {
        $app->log->error("CRASH in handle_play for " . $player->id . ": $@");
        $controller->send({json => {
            type    => 'error',
            payload => "Fecking server error!"
        }});
    }
}

sub _perform_play ($self, $controller, $player, $payload, $word, $game_data, $game_record) {
    my $app = $self->app;
    my $rack = $game_record->rack;
    my $lang = $game_record->language // $DEFAULT_LANG;

    $app->log->debug("Checking word '$word' against player rack [" . join('', @{$rack}) . "]");
    unless ($app->scorer->can_form_word($word, $rack)) {
        $app->log->debug("Word '$word' FAILED rack check");
        return $controller->send({json => {
            type    => 'error',
            payload => $controller->t('error.missing_letters', $lang)
        }});
    }

    # Non-blocking validation via wordd
    $app->wordd->validate($word, $lang, sub ($res) {
        if ($res && $res->is_success) {
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
            
            # Calculate achievement emojis
            my $actual_rack_size = (ref($game_record->rack) eq 'ARRAY' ? scalar(@{$game_record->rack}) : 0);
            my $len_bonus = $app->scorer->get_length_bonus($word, $actual_rack_size);
            my $total_points = $score + $len_bonus;

            my @emojis;
            my $game_data = $app->games->{$game_record->id};
            if ($game_data && $game_data->{state}) {
                # ⚡ Quick Bonus
                my $quick_bonus_seconds = $ENV{QUICK_BONUS_SECONDS} || 5;
                my $elapsed = (time - $game_data->{state}->started_at->epoch);
                push @emojis, '⚡' if $elapsed <= $quick_bonus_seconds;

                # 💯 Full Rack
                push @emojis, '💯' if length($word) >= $actual_rack_size;

                # ✨ Any other instant bonus, such as for word length
                push @emojis, '✨' if $len_bonus > 0;
            }

            # 📅 Daily Bonus (Calendar emoji if word contains the day's special letter)
            # This is independent of volatile state and always works if the char is present
            my $bonus_char = $app->scorer->get_daily_bonus_char();
            push @emojis, '📅' if index(uc($word), $bonus_char) != -1;
            my $emoji_prefix = @emojis ? join('', @emojis) . ' ' : '';

            # Also send a chat message for the play (restricting to game scope)
            my $tile_count = length($word);
            my $chat_msg = $controller->t('app.played_word', $lang, { 
                player     => $player->nickname, 
                tile_count => $tile_count,
                raw_points => $score
            });
            my $timestamp = time;
            # Broadcast to everyone in the game
            $controller->broadcast_to_game({
                type    => 'chat',
                sender  => 'SYSTEM',
                payload => {
                    text       => $emoji_prefix . $chat_msg,
                    senderName => $player->nickname,
                    isSystem   => 1,
                },
                timestamp => $timestamp,
            }, $game_record->id);

            my $game_clients = $game_data->{clients} // {};
            for my $pid (keys %$game_clients) {
                my $c = $game_clients->{$pid};
                next unless $c && $c->tx;

                my $is_sender = $pid eq $player->id;
                $c->send({json => {
                    type      => 'play',
                    sender    => $player->id,
                    timestamp => $timestamp,
                    payload   => {
                        playerName   => $player->nickname,
                        word         => $is_sender ? $word : undef,
                        score        => $total_points,
                        raw_points   => $score,
                        length_bonus => $len_bonus,
                        msg          => $emoji_prefix . $chat_msg,
                    }
                }});
            }

            # AI Reacts if beaten
            $_->check_reaction($player->nickname, $score) for @{$game_data->{ais} // []};
        }
        else {
            my $code = $res->code // 0;
            $app->log->debug("Word '$word' REJECTED by wordd. Status: $code");
            
            my $msg = ($code == 404) 
                ? $controller->t('app.error_word_not_found', $lang, { word => $word })
                : "Fecking server error!";

            $controller->send({json => {
                type    => 'error',
                payload => $msg
            }});
        }
    });
}

sub start_game_timer ($self, $game) {
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
        
        # Drive AI
        my $total_dur = $ENV{GAME_DURATION} || $DEFAULT_GAME_DURATION;
        my $elapsed = $total_dur - $g->{time_left};
        
        my $rack = $game->rack // [];
        my $rack_str = join('', map { ref $_ ? ($_->{letter} // '') : $_ } @$rack);

        for my $ai (@{$g->{ais} // []}) {
            # AI fetches candidates once Game has rack/letter_values (usually first second)
            if ($elapsed == 1) {
                $app->log->debug("AI " . $ai->nickname . " fetching candidates for rack_str: $rack_str");
                $ai->fetch_candidates($rack_str);
            }
            $ai->tick($elapsed);
        }
        
        # Broadcast timer update
        $app->broadcaster->announce_to_game({
            type    => 'timer',
            payload => { time_left => ($g->{time_left} > 0 ? $g->{time_left} : 0) }
        }, $gid);

        if ($g->{time_left} <= 0) {
            $loop->remove($timer_id);
            # Buffer for network latency / last second submissions
            Mojo::IOLoop->timer(2 => sub { $self->end_game($game) });
        }
    });
}

sub end_game ($self, $game) {
    my $app = $self->app;
    my $schema = $app->schema;
    my $game_id = $game->id;
    $app->log->debug("Starting end_game for $game_id");
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

    my $game_lang = $game->language // $DEFAULT_LANG;
    my @ai_pids = map { $_->player_id } @{$app->games->{$game_id}{ais} // []};

    my $actual_rack_size = (ref($game->rack) eq 'ARRAY' ? scalar(@{$game->rack}) : 8);
    my $results = $app->state_processor->calculate_results(\@plays, $game_lang, $game->started_at, $actual_rack_size);
    my $solo_game = $app->state_processor->is_solo(\@plays, \@ai_pids);

    $app->log->debug("Ending game $game_id - Found " . scalar(@plays) . " plays. Solo: " . ($solo_game ? "YES" : "NO"));

    # Update player cumulative scores in database (skip for solo games)
    if (!$solo_game) {
        for my $result (@$results) {
            my $player = $schema->resultset('Player')->find($result->{player_id});
            if ($player) {
                # Skip AI player updates
                my %is_ai = map { $_ => 1 } @ai_pids;
                next if $is_ai{$player->id};

                my $old_score = $player->lifetime_score || 0;
                my $new_score = $old_score + $result->{score};
                $player->update({ lifetime_score => $new_score });
            }
        }
    }

    my $winner = $results->[0];
    my $winner_word = $winner ? $winner->{word} : undef;
    my $winner_lang = $game->language // $DEFAULT_LANG;
    
    # Build results for payload
    my $results_payload = $results; # Use StateProcessor's enhanced output

    my ($send_results, $wrap_send, $timer);
    
    $send_results = sub ($definition = undef, $suggested_word = undef) {
        my $summary = $winner 
            ? $app->t('results.winner_summary', $winner_lang, { name => $winner->{player}, score => $winner->{score}, word => $winner->{word} }) 
            : $app->t('results.no_winner', $winner_lang);

        my $history_msg = {
            type      => 'chat',
            sender    => 'SYSTEM',
            timestamp => time,
            payload   => {
                text       => $summary,
                senderName => 'SYSTEM',
                isSystem   => 1,
                type       => 'results_table',
                data       => $results_payload,
            }
        };

        # Global Announcement
        my @game_pids = keys %{$app->games->{$game_id}{clients} // {}};
        $app->broadcaster->announce_all_but($history_msg, \@game_pids);

        $app->broadcast_to_game({
            type      => 'game_end',
            timestamp => time,
            payload   => {
                results => $results_payload,
                is_solo => $solo_game,
                summary => $summary,
                definition     => $definition,
                suggested_word => $suggested_word,
            }
        }, $game_id);
        
        $app->log->debug("Finished broadcasting game_end for $game_id. Deleting game from memory.");
        delete $app->games->{$game_id};
    };

    # Safety: If we're still here after 3 seconds, just send what we have
    $timer = Mojo::IOLoop->timer(3 => sub {
        return unless $timer;
        $timer = undef;
        $app->log->warn("End game broadcast safety triggered for $game_id - suggest/define took too long");
        $send_results->();
    });

    $wrap_send = sub ($def = undef, $sug = undef) {
        return unless $timer;
        Mojo::IOLoop->remove($timer);
        $timer = undef;
        $send_results->($def, $sug);
    };

    my $suggest_cb = sub ($suggested_res = undef) {
        my $suggested_word;
        if ($suggested_res && $suggested_res->is_success) {
            $suggested_word = uc(Mojo::Util::trim($suggested_res->body));
        }

        if ($winner_word) {
            $app->wordd->define($winner_word, $winner_lang, sub ($def_res = undef) {
                $wrap_send->($def_res && $def_res->is_success ? $def_res->body : undef, $suggested_word);
            });
        } else {
            $wrap_send->(undef, $suggested_word);
        }
    };

    my $clean_rack = join('', grep { /[A-Z]/ } @{$game->rack});
    $app->wordd->suggest($clean_rack, $winner_lang, $suggest_cb);
}

sub handle_disconnect ($self, $player_id) {
    my $app = $self->app;
    for my $game_id (keys %{$app->games}) {
        my $game = $app->games->{$game_id};
        if (exists $game->{clients}{$player_id}) {
            my $player = $app->schema->resultset('Player')->find($player_id);
            if ($player) {
                $app->broadcaster->announce_to_game({
                    type    => 'player_quit',
                    payload => {
                        id   => $player->id,
                        name => $player->nickname,
                    }
                }, $game_id, [$player_id]);
            }
            delete $game->{clients}{$player_id};
        }
    }
}

sub handle_set_language ($self, $controller, $player, $payload) {
    my $app = $self->app;
    my $lang = $payload->{language} // $DEFAULT_LANG;
    $player->update({ language => $lang });
    $app->log->debug("Player " . $player->id . " set language to $lang");

    # 1. Exit current game
    $self->handle_disconnect($player->id);

    # 2. Re-send FULL configuration for the new language
    $controller->send({json => {
        type    => 'identity',
        payload => { 
            id       => $player->id, 
            name     => $player->nickname, 
            language => $lang,
            config   => {
                tiles       => $app->scorer->tile_counts($lang),
                unicorns    => $app->scorer->unicorns($lang),
                tile_values => $app->scorer->generate_tile_values($lang),
                languages   => $app->languages,
            }
        }
    }});

    # 3. Join game in the new language
    $self->join_player($controller, $player);
}

# --- Utilities ---

sub _have_encountered ($self, $p1_id, $p2_id) {
    my $schema = $self->app->schema;
    # Check if they share any game_id in the plays table
    my $shared_games = $schema->resultset('Play')->search(
        { player_id => $p1_id },
        { select => ['game_id'] }
    );
    my $count = $schema->resultset('Play')->search(
        { 
            player_id => $p2_id,
            game_id   => { -in => $shared_games->get_column('game_id')->as_query }
        }
    )->count;
    return $count > 0;
}

sub _get_player_game ($self, $player_id) {
    for my $game (values %{$self->app->games}) {
        return $game if exists $game->{clients}{$player_id};
    }
    return undef;
}

1;
