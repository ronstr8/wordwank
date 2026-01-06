package game

import (
	"math/rand"
	"strings"
	"time"
)

var letterValues = map[rune]int{
	'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4, 'G': 2, 'H': 4, 'I': 1, 'J': 8, 'K': 5, 'L': 1,
	'M': 3, 'N': 1, 'O': 1, 'P': 3, 'Q': 10, 'R': 1, 'S': 1, 'T': 1, 'U': 2, 'V': 4, 'W': 4, 'X': 8,
	'Y': 4, 'Z': 10, '_': 0,
}

var tileCounts = map[rune]int{
	'A': 9, 'B': 2, 'C': 2, 'D': 4, 'E': 12, 'F': 2, 'G': 3, 'H': 2, 'I': 9, 'J': 1, 'K': 1, 'L': 4,
	'M': 2, 'N': 6, 'O': 8, 'P': 2, 'Q': 1, 'R': 6, 'S': 4, 'T': 6, 'U': 4, 'V': 2, 'W': 2, 'X': 1,
	'Y': 2, 'Z': 1,
}

var bag []rune
var vowels = "AEIOU"

func init() {
	rand.Seed(time.Now().UnixNano())
	for char, count := range tileCounts {
		for i := 0; i < count; i++ {
			bag = append(bag, char)
		}
	}
}

type Scorer struct{}

func (s *Scorer) GetRandomRack() []string {
	for {
		perm := rand.Perm(len(bag))
		var rack []string
		hasVowel := false
		for i := 0; i < 7; i++ {
			r := bag[perm[i]]
			rack = append(rack, string(r))
			if strings.ContainsRune(vowels, r) {
				hasVowel = true
			}
		}
		if hasVowel {
			return rack
		}
	}
}

func (s *Scorer) CalculateWordScore(word string) int {
	score := 0
	for _, r := range word {
		if r >= 'a' && r <= 'z' {
			continue
		}
		score += letterValues[r]
	}
	return score
}

type PlayResult struct {
	Player     string           `json:"player"`
	Word       string           `json:"word"`
	Score      int              `json:"score"`
	Exceptions []map[string]int `json:"exceptions"`
	DupedBy    []string         `json:"duped_by"`
}

func (s *Scorer) CalculateFinalScores(plays []Play) []PlayResult {
	seen := make(map[string]string)
	dupers := make(map[string][]string)
	var results []PlayResult

	for _, p := range plays {
		normalized := strings.ToLower(p.Word)
		res := PlayResult{
			Player:     p.Player,
			Word:       p.Word,
			Score:      p.Score,
			Exceptions: []map[string]int{},
			DupedBy:    []string{},
		}

		if _, exists := seen[normalized]; exists {
			dupers[normalized] = append(dupers[normalized], p.Player)
			res.Score = 0
		} else {
			seen[normalized] = p.Player
			dupers[normalized] = []string{}
		}

		if len(p.Word) == 7 {
			res.Exceptions = append(res.Exceptions, map[string]int{"Used all tiles!": 10})
			res.Score += 10
		}
		results = append(results, res)
	}

	for i := range results {
		normalized := strings.ToLower(results[i].Word)
		if seen[normalized] == results[i].Player {
			dupeCount := len(dupers[normalized])
			if dupeCount > 0 {
				results[i].Score += dupeCount
				results[i].Exceptions = append(results[i].Exceptions, map[string]int{"Subsequent dupes": dupeCount})
				results[i].DupedBy = dupers[normalized]
			}
		}
	}

	uniqueCount := 0
	var soleWord string
	for i := range results {
		if results[i].Score > 0 {
			uniqueCount++
			soleWord = strings.ToLower(results[i].Word)
		}
	}

	if uniqueCount == 1 {
		totalDupes := 0
		for i := range results {
			if results[i].Score == 0 {
				totalDupes++
			}
		}
		for i := range results {
			if strings.ToLower(results[i].Word) == soleWord && results[i].Score > 0 {
				results[i].Score += totalDupes
				results[i].Exceptions = append(results[i].Exceptions, map[string]int{"Sole unique word": totalDupes})
			}
		}
	}

	return results
}
