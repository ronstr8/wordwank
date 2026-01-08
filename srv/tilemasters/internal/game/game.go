package game

import (
	"fmt"
	"sync"
	"time"
)

type Play struct {
	Player string `json:"player"`
	Word   string `json:"word"`
	Score  int    `json:"score"`
	Time   int64  `json:"time"`
}

type Game struct {
	UUID        string    `json:"uuid"`
	Rack        []string  `json:"rack"`
	Plays       []Play    `json:"plays"`
	StartTime   time.Time `json:"start_time"`
	Duration    float64   `json:"duration"`
	LetterValue int       `json:"letter_value,omitempty"`
	mu          sync.Mutex
}

func NewGame(uuid string, rack []string, letterValue int) *Game {
	return &Game{
		UUID:        uuid,
		Rack:        rack,
		Plays:       []Play{},
		StartTime:   time.Now(),
		Duration:    60,
		LetterValue: letterValue,
	}
}

func (g *Game) TimeLeft() float64 {
	elapsed := time.Since(g.StartTime).Seconds()
	left := g.Duration - elapsed
	if left < 0 {
		return 0
	}
	return left
}

func (g *Game) AddPlay(player, word string, scorer *Scorer, validator Validator) (Play, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	if !validator.ValidateWord(word) {
		return Play{}, fmt.Errorf("invalid word")
	}

	score := scorer.CalculateWordScore(word, g.LetterValue)

	newPlays := []Play{}
	for _, p := range g.Plays {
		if p.Player != player {
			newPlays = append(newPlays, p)
		}
	}
	play := Play{
		Player: player,
		Word:   word,
		Score:  score,
		Time:   time.Now().Unix(),
	}
	g.Plays = append(newPlays, play)

	return play, nil
}
