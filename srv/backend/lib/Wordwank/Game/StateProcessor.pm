package Wordwank::Game::StateProcessor;
use Moose;
use v5.36;
use utf8;

has 'app' => ( is => 'ro', required => 1 );

sub calculate_results ($self, $plays, $game_lang) {
    my $scorer = $self->app->scorer;
    
    my %word_to_players;
    my %player_bonuses;  # player_id -> { duplicates => count, length_bonus => count, unique => count, duped_by => [ { name => nickname, bonus => 1 } ] }
    my %is_duper;  # player_id -> 1 if they duplicated someone
    my %player_id_to_nickname;
    
    for my $play (@$plays) {
        my $word = $play->get_column('word');
        my $player_id = $play->get_column('player_id');
        
        push @{$word_to_players{$word}}, $player_id;
        $player_id_to_nickname{$player_id} = $play->get_column('player');
        
        # Initialize bonus tracking for this player
        $player_bonuses{$player_id} //= { duplicates => 0, unique => 0, length_bonus => 0, duped_by => [] };
        
        # Calculate length bonus
        my $bonus = $scorer->get_length_bonus($word);
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
    
    # Build enhanced results with bonuses
    my %player_total_scores;  # Track total scores including bonuses
    
    for my $play (@$plays) {
        my $player_id = $play->get_column('player_id');
        my $word = $play->get_column('word');
        my $base_score = $play->get_column('score');
        my $bonuses = $player_bonuses{$player_id};
        
        my $duplicate_bonus = $bonuses->{duplicates} || 0;
        my $unique_bonus = $bonuses->{unique} || 0;
        my $length_bonus = $bonuses->{length_bonus} || 0;
        
        my $total_score;
        if ($is_duper{$player_id}) {
            $total_score = 0;
        } else {
            $total_score = $base_score + $duplicate_bonus + $unique_bonus + $length_bonus;
        }
        
        # Track highest score per player
        if (!exists $player_total_scores{$player_id} || $total_score > $player_total_scores{$player_id}{score}) {
            $player_total_scores{$player_id} = {
                player_id       => $player_id,
                player          => $play->get_column('player'),  # nickname for display
                word            => $word,
                score           => $total_score,
                base_score      => $is_duper{$player_id} ? 0 : $base_score,
                duplicate_bonus => $duplicate_bonus,
                unique_bonus    => $unique_bonus,
                length_bonus    => $length_bonus,
                duped_by        => $bonuses->{duped_by} // [],
                is_dupe         => $is_duper{$player_id} ? 1 : 0,
                created_at      => $play->get_column('created_at'),
            };
        }
    }
    
    # Convert to sorted array
    my @results = sort { 
        $b->{score} <=> $a->{score} 
        || $a->{created_at} cmp $b->{created_at} 
    } values %player_total_scores;
    
    return \@results;
}

sub is_solo ($self, $plays, $ai_player_id) {
    my %seen_players = map { $_->get_column('player_id') => 1 } @$plays;
    
    my $humans_seen = 0;
    for my $pid (keys %seen_players) {
        $humans_seen++ unless $ai_player_id && $pid eq $ai_player_id;
    }
    
    # Solo is only true if only 1 human and NO ai.
    # Actually, the logic in Game.pm was:
    # my $has_ai = $app->games->{$game->id}{ai} ? 1 : 0;
    # my $solo_game = ($humans_seen <= 1 && !$has_ai);
    
    # We'll pass has_ai as a parameter to be cleaner or check if ai_player_id is provided.
    return ($humans_seen <= 1 && !$ai_player_id);
}

1;
