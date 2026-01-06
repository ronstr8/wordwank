package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"

	"tilemasters/internal/game"

	"github.com/google/uuid"
)

var (
	games     = make(map[string]*game.Game)
	gamesMu   sync.RWMutex
	scorer    = &game.Scorer{}
	validator game.Validator
)

func init() {
	worddHost := os.Getenv("WORDD_HOST")
	if worddHost == "" {
		worddHost = "http://wordd"
	}
	validator = &game.RemoteValidator{WorddURL: worddHost}
}

func handleCreateGame(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	gameUUID := uuid.New().String()
	rack := scorer.GetRandomRack()
	newGame := game.NewGame(gameUUID, rack)

	gamesMu.Lock()
	games[gameUUID] = newGame
	gamesMu.Unlock()

	json.NewEncoder(w).Encode(map[string]interface{}{
		"uuid": gameUUID,
		"rack": rack,
	})
}

func handlePlay(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 4 {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}
	gameUUID := parts[1]
	word := parts[3]

	gamesMu.RLock()
	g, exists := games[gameUUID]
	gamesMu.RUnlock()

	if !exists {
		http.Error(w, "Game not found", http.StatusNotFound)
		return
	}

	authHeader := r.Header.Get("Authorization")
	player := "player-123"
	if authHeader == "" {
		player = "anonymous"
	}

	play, err := g.AddPlay(player, word, scorer, validator)
	if err != nil {
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"score":   play.Score,
	})
}

func handleEndGame(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 3 {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}
	gameUUID := parts[1]

	gamesMu.RLock()
	g, exists := games[gameUUID]
	gamesMu.RUnlock()

	if !exists {
		http.Error(w, "Game not found", http.StatusNotFound)
		return
	}

	results := scorer.CalculateFinalScores(g.Plays)
	json.NewEncoder(w).Encode(results)
}

func main() {
	http.HandleFunc("/game", handleCreateGame)
	http.HandleFunc("/game/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/play") || strings.Contains(r.URL.Path, "/play/") {
			handlePlay(w, r)
		} else if strings.HasSuffix(r.URL.Path, "/end") {
			handleEndGame(w, r)
		} else {
			http.NotFound(w, r)
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3883"
	}

	log.Printf("Tilemasters (Go) starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
