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
has 'played'          => 0;
has 'thinking_times'  => sub { [] };
has 'last_score'      => 0;
has 'reacted_beaten'  => 0;

sub new_for_game ($class, $app, $game_id, $language) {
    my $self = $class->new(
        app     => $app,
        game_id => $game_id,
        language => $language,
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
    my $url = "${wordd_base}rand/langs/$lang/word?letters=$rack_str&count=$count";

    $self->app->ua->get($url => sub ($ua, $tx) {
        if ($tx->result->is_success) {
            my $body = $tx->result->body;
            my @words = split /\n/, $body;
            $self->candidates(\@words);
            $self->app->log->debug("AI " . $self->nickname . " fetched " . scalar(@words) . " candidates");
        } else {
            $self->app->log->error("AI " . $self->nickname . " failed to fetch words: " . $tx->result->message);
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
    my @scored = map {
        { word => $_, score => $self->app->scorer->calculate_score($_, $game_record->letter_values) }
    } @$words;

    # Filter by min score
    @scored = grep { $_->{score} >= $self->min_score_to_play } @scored;
    return unless @scored;

    # Sort DESC
    @scored = sort { $b->{score} <=> $a->{score} } @scored;

    my $chosen;
    if ($scored[0]{score} >= $self->min_score_to_win) {
        $chosen = $scored[0];
    } else {
        # Random pick among candidates
        $chosen = $scored[int(rand(@scored))];
    }

    $self->played(1);
    $self->last_score($chosen->{score});
    
    # We "play" by directly inserting into DB and broadcasting, 
    # similar to _perform_play in Game.pm
    $self->_execute_play($chosen->{word}, $chosen->{score}, $game_record);
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
