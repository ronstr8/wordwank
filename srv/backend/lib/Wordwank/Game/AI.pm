package Wordwank::Game::AI;
use Mojo::Base -base, -signatures;
use Mojo::Util;
use UUID::Tiny qw(:std);
use Wordwank::Util::NameGenerator;

has 'app';
has 'game_id';
has 'player_id' => sub { create_uuid_as_string(UUID_V4) };
has 'nickname'  => sub { Wordwank::Util::NameGenerator->new->generate(4, 1) };
has 'language'  => 'en';

# AI Config
has 'wait_seconds_base' => 5;
has 'rnd_word_count'    => 5;
has 'min_score_to_play' => 2;
has 'min_score_to_win'  => 30;

# Instance state
has 'candidates'      => sub { [] };
has 'play_time'       => 0;
has 'player_id';
has 'nickname'  => sub { 'WankBot' };
has 'language'  => 'en';
has 'played'          => 0;
has 'thinking_times'  => sub { [] };
has 'last_score'      => 0;
has 'reacted_beaten'  => 0;

# Bot Profiles
my %PROFILES = (
    'The Worm' => {
        uuid              => '00000000-0000-4000-a000-000000000001',
        wait_seconds_base => 15,
        rnd_word_count    => 3,
        min_score_to_play => 1,
        min_score_to_win  => 40,
    },
    'QuickSilver' => {
        uuid              => '00000000-0000-4000-a000-000000000002',
        wait_seconds_base => 5,
        rnd_word_count    => 5,
        min_score_to_play => 5,
        min_score_to_win  => 35,
    },
    'WankMaster' => {
        uuid              => '00000000-0000-4000-a000-000000000003',
        wait_seconds_base => 8,
        rnd_word_count    => 8,
        min_score_to_play => 10,
        min_score_to_win  => 25,
    },
    'Sir Scrabble' => {
        uuid              => '00000000-0000-4000-a000-000000000004',
        wait_seconds_base => 12,
        rnd_word_count    => 10,
        min_score_to_play => 15,
        min_score_to_win  => 20,
    },
);

sub new_for_game ($class, $app, $game_id, $language) {
    # Pick a random bot profile
    my @bots = keys %PROFILES;
    my $bot_name = $bots[int(rand(@bots))];
    my $config = $PROFILES{$bot_name};

    # Ensure player exists in DB
    $app->schema->resultset('Player')->find_or_create({
        id       => $config->{uuid},
        nickname => $bot_name,
    });

    my $self = $class->new(
        app       => $app,
        game_id   => $game_id,
        language  => $language,
        nickname  => $bot_name,
        player_id => $config->{uuid},
        %$config,
    );
    $self->_init_schedule();
    return $self;
}

sub _init_schedule ($self) {
    my $total_dur = $ENV{GAME_DURATION} || 30;
    
    # Random play time between base and duration
    my $range = $total_dur - $self->wait_seconds_base;
    $range = 1 if $range < 1;
    $self->play_time($self->wait_seconds_base + int(rand($range)));
    
    # 1-2 thinking chats
    my $chats = 1 + int(rand(2));
    my @thinking;
    for (1 .. $chats) {
        push @thinking, 2 + int(rand($self->play_time - 2)) if $self->play_time > 3;
    }
    $self->thinking_times([ sort { $a <=> $b } @thinking ]);
}

sub fetch_candidates ($self, $rack_str) {
    my $lang = $self->language;
    my $count = $self->rnd_word_count;
    my $wordd_base = $ENV{WORDD_URL} || "http://wordd:2345/";
    
    my $letters = $rack_str;
    $letters =~ s/_/?/g; # wordd uses ? for wildcards
    
    my $url = "${wordd_base}rand/langs/$lang/word?letters=$letters&count=$count";

    $self->app->ua->get($url => sub ($ua, $tx) {
        if ($tx->result->is_success) {
            my $body = $tx->result->body;
            my @words = split /\n/, $body;
            # Ensure they are uppercase and trimmed
            @words = map { uc(Mojo::Util::trim($_)) } grep { /\S/ } @words;
            $self->candidates(\@words);
            $self->app->log->debug("AI " . $self->nickname . " fetched " . scalar(@words) . " candidates for letters '$letters'");
        } else {
            $self->app->log->error("AI " . $self->nickname . " failed to fetch words for '$letters': " . $tx->result->message);
        }
    });
}

sub tick ($self, $seconds_elapsed) {
    return if $self->played;

    # Time to play?
    if ($seconds_elapsed >= $self->play_time) {
        $self->play_best_word();
        return;
    }

    # Time to think?
    if (@{$self->thinking_times} && $seconds_elapsed >= $self->thinking_times->[0]) {
        shift @{$self->thinking_times};
        $self->chat('ai.thinking');
    }
}

sub play_best_word ($self) {
    my $words = $self->candidates;
    return unless @$words;

    my $game_data = $self->app->games->{$self->game_id};
    return unless $game_data;
    my $game_record = $game_data->{state};

    # Calculate scores for all candidates
    my @scored;
    my %seen_words;
    for my $w (@$words) {
        next if $seen_words{$w}++;
        push @scored, { word => $w, score => $self->app->scorer->calculate_score($w, $game_record->letter_values) };
    }

    # Sort DESC
    @scored = sort { $b->{score} <=> $a->{score} } @scored;

    my $chosen;
    # Filter by min score for "good" plays
    my @filtered = grep { $_->{score} >= $self->min_score_to_play } @scored;

    if (@filtered) {
        if ($filtered[0]{score} >= $self->min_score_to_win) {
            $chosen = $filtered[0];
            $self->app->log->debug("AI " . $self->nickname . " chose high-score word: " . $chosen->{word} . " (" . $chosen->{score} . ")");
        } else {
            # Random pick among valid-enough candidates
            $chosen = $filtered[int(rand(@filtered))];
            $self->app->log->debug("AI " . $self->nickname . " chose random word: " . $chosen->{word} . " (" . $chosen->{score} . ")");
        }
    } elsif (@scored) {
        # FALLBACK: Just pick any valid word if no words meet the AI's "pride" threshold
        # This prevents the AI from just skipping multiple rounds
        $chosen = $scored[0];
        $self->app->log->debug("AI " . $self->nickname . " using fallback play: " . $chosen->{word} . " (" . $chosen->{score} . ")");
    }

    if ($chosen) {
        $self->played(1);
        $self->last_score($chosen->{score});
        $self->_execute_play($chosen->{word}, $chosen->{score}, $game_record);
    } else {
        $self->app->log->debug("AI " . $self->nickname . " found NO valid plays this round (candidates: " . scalar(@$words) . ")");
    }
}

sub _execute_play ($self, $word, $score, $game_record) {
    my $app = $self->app;
    
    # Persist the play (AI players don't save ranking, but their round play is recorded)
    $app->schema->resultset('Play')->create({
        game_id   => $game_record->id,
        player_id => $self->player_id,
        word      => $word,
        score     => $score,
    });

    $app->log->debug("AI " . $self->nickname . " played: $word ($score pts)");

    # Broadcast
    # Broadcast using the app's broadcaster (safer than manual loop)
    my $timestamp = time;
    my $msg = {
        type      => 'play',
        sender    => $self->player_id,
        timestamp => $timestamp,
        payload   => {
            playerName => $self->nickname,
            word       => undef,
            score      => $score,
            msg        => $self->nickname . " played a word for $score pts!",
        }
    };
    $app->broadcaster->announce_to_game($msg, $self->game_id);
}

sub chat ($self, $key, $args = {}) {
    my $lang = $self->language;
    my $msg_pool = $self->app->t($key, $lang);
    
    my $text = $self->app->t($key, $lang, $args);

    # Send directly to this game's players
    my $msg = {
        type    => 'chat',
        sender  => $self->player_id,
        payload => {
            text       => $text,
            senderName => $self->nickname,
        }
    };
    $self->app->broadcaster->announce_to_game($msg, $self->game_id);
}

sub check_reaction ($self, $player_name, $player_score) {
    return if $self->reacted_beaten;
    return unless $self->last_score > 0;

    if ($player_score > $self->last_score) {
        $self->reacted_beaten(1);
        $self->chat('ai.reaction_beaten', { player => $player_name });
    }
}

1;
