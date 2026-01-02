package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

func registerPlayerWithService(id string) {
	resp, err := http.PostForm("http://playerd:8080/players/"+id, url.Values{"username": {id}})
	if err != nil {
		log.Printf("Failed to register player %s: %v", id, err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	log.Printf("Player %s registered: %s", id, string(body))
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // In production, refine this
	},
}

type Client struct {
	ID   string
	Conn *websocket.Conn
}

type Message struct {
	Type      string      `json:"type"`
	Payload   interface{} `json:"payload"`
	Sender    string      `json:"sender,omitempty"`
	Timestamp int64       `json:"timestamp"`
}

type GameState struct {
	UUID     string        `json:"uuid"`
	Rack     []string      `json:"rack"`
	TimeLeft int           `json:"time_left"`
	IsActive bool          `json:"is_active"`
	Results  []interface{} `json:"results,omitempty"`
}

type Gateway struct {
	clients    map[string]*Client
	register   chan *Client
	unregister chan *Client
	broadcast  chan Message
	game       *GameState
	mu         sync.Mutex
}

func NewGateway() *Gateway {
	return &Gateway{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan Message),
		game:       &GameState{IsActive: false},
	}
}

func (g *Gateway) StartGame() {
	// Call tilemasters to get a rack and UUID
	resp, err := http.Post("http://tilemasters:3883/game", "application/json", nil)
	if err != nil {
		log.Printf("Failed to start game: %v", err)
		return
	}
	defer resp.Body.Close()

	var data struct {
		UUID string   `json:"uuid"`
		Rack []string `json:"rack"`
	}
	json.NewDecoder(resp.Body).Decode(&data)

	g.mu.Lock()
	g.game = &GameState{
		UUID:     data.UUID,
		Rack:     data.Rack,
		TimeLeft: 60,
		IsActive: true,
	}
	g.mu.Unlock()

	g.broadcast <- Message{
		Type:      "game_start",
		Payload:   g.game,
		Timestamp: time.Now().Unix(),
	}

	// Start timer ticker
	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			g.mu.Lock()
			if !g.game.IsActive {
				ticker.Stop()
				g.mu.Unlock()
				return
			}
			g.game.TimeLeft--
			timeLeft := g.game.TimeLeft
			g.mu.Unlock()

			if timeLeft <= 0 {
				ticker.Stop()
				g.EndGame()
				return
			}
		}
	}()
}

func (g *Gateway) EndGame() {
	g.mu.Lock()
	if !g.game.IsActive {
		g.mu.Unlock()
		return
	}
	g.game.IsActive = false
	gameUUID := g.game.UUID
	g.mu.Unlock()

	// Fetch final scores from tilemasters
	resp, err := http.Post(fmt.Sprintf("http://tilemasters:3883/game/%s/end", gameUUID), "application/json", nil)
	if err != nil {
		log.Printf("Failed to end game: %v", err)
		return
	}
	defer resp.Body.Close()

	var results []map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&results)

	// Report scores and get definition for winner
	var summaryText string
	if len(results) > 0 {
		winner := results[0]
		winningWord := winner["word"].(string)
		winnerID := winner["player"].(string)

		// Report scores to playerd
		for _, res := range results {
			pID := res["player"].(string)
			pScoreRaw := res["score"]

			// Handle score as float64 from JSON decoding
			var pScore int64
			if f, ok := pScoreRaw.(float64); ok {
				pScore = int64(f)
			} else if i, ok := pScoreRaw.(int64); ok {
				pScore = i
			}

			if pScore > 0 {
				http.PostForm(fmt.Sprintf("http://playerd:8080/players/%s/score", pID), url.Values{"score": {fmt.Sprintf("%d", pScore)}})
			}
		}

		// Get definition for winning word from wordd
		defResp, err := http.Get(fmt.Sprintf("http://wordd:2345/word/%s", winningWord))
		if err == nil && defResp.StatusCode == 200 {
			defer defResp.Body.Close()
			defBody, _ := io.ReadAll(defResp.Body)
			winner["definition"] = string(defBody)
		}

		summaryText = fmt.Sprintf("%s wins the game with \"%s\" for a total of %v points.", winnerID, winningWord, winner["score"])
	}

	g.broadcast <- Message{
		Type: "game_over",
		Payload: map[string]interface{}{
			"results": results,
			"summary": summaryText,
		},
		Timestamp: time.Now().Unix(),
	}

	// Restart game after 10 seconds
	time.AfterFunc(10*time.Second, func() {
		g.StartGame()
	})
}

func (g *Gateway) Run() {
	for {
		select {
		case client := <-g.register:
			g.mu.Lock()
			g.clients[client.ID] = client
			g.mu.Unlock()
			fmt.Printf("Client registered: %s\n", client.ID)

		case client := <-g.unregister:
			g.mu.Lock()
			if _, ok := g.clients[client.ID]; ok {
				delete(g.clients, client.ID)
				client.Conn.Close()
				fmt.Printf("Client unregistered: %s\n", client.ID)
			}
			g.mu.Unlock()

		case message := <-g.broadcast:
			msgBytes, err := json.Marshal(message)
			if err != nil {
				log.Printf("error: %v", err)
				continue
			}
			g.mu.Lock()
			for _, client := range g.clients {
				err := client.Conn.WriteMessage(websocket.TextMessage, msgBytes)
				if err != nil {
					log.Printf("error writing message: %v", err)
					client.Conn.Close()
					delete(g.clients, client.ID)
				}
			}
			g.mu.Unlock()
		}
	}
}

func (g *Gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("upgrade error: %v", err)
		return
	}

	clientID := r.URL.Query().Get("id")
	if clientID == "" {
		clientID = fmt.Sprintf("anon-%d", time.Now().UnixNano())
	}

	go registerPlayerWithService(clientID)

	client := &Client{ID: clientID, Conn: conn}
	g.register <- client

	// Send current game state to new client
	g.mu.Lock()
	if g.game.IsActive {
		stateBytes, _ := json.Marshal(Message{
			Type:      "game_start",
			Payload:   g.game,
			Timestamp: time.Now().Unix(),
		})
		client.Conn.WriteMessage(websocket.TextMessage, stateBytes)
	}
	g.mu.Unlock()

	defer func() {
		g.unregister <- client
	}()

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("read error: %v", err)
			break
		}

		var msg Message
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("unmarshal error: %v", err)
			continue
		}

		msg.Timestamp = time.Now().Unix()
		msg.Sender = clientID

		// Handle message types
		switch msg.Type {
		case "chat":
			g.broadcast <- msg
		case "play":
			g.mu.Lock()
			gameUUID := g.game.UUID
			isActive := g.game.IsActive
			g.mu.Unlock()

			if !isActive {
				continue
			}

			// Forward to Tilemasters service
			word := msg.Payload.(map[string]interface{})["word"].(string)
			playURL := fmt.Sprintf("http://tilemasters:3883/game/%s/play/%s", gameUUID, word)
			req, _ := http.NewRequest("GET", playURL, nil)
			req.Header.Set("Authorization", clientID)

			resp, err := http.DefaultClient.Do(req)
			if err == nil {
				defer resp.Body.Close()
				var result map[string]interface{}
				json.NewDecoder(resp.Body).Decode(&result)

				if _, hasError := result["error"]; !hasError {
					// Only broadcast if the word was valid (or at least accepted)
					msg.Payload = result // Include score if returned
					g.broadcast <- msg
				}
			}
		default:
			log.Printf("Unknown message type: %s", msg.Type)
		}
	}
}

func main() {
	gateway := NewGateway()
	go gateway.Run()

	// Wait a bit for other services to be up then start the game loop
	time.AfterFunc(5*time.Second, func() {
		gateway.StartGame()
	})

	http.Handle("/ws", gateway)
	fmt.Println("GatewayD starting on :8081...")
	if err := http.ListenAndServe(":8081", nil); err != nil {
		log.Fatal("ListenAndServe:", err)
	}
}
