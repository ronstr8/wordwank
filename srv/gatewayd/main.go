package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var (
	adjectives = []string{"Funny", "Serious", "Clumsy", "Swift", "Brave", "Quiet", "Loud", "Happy", "Sad", "Zen", "Mad", "Groovy", "Funkie", "Mighty", "Wobbly", "Salty", "Spicy", "Cool", "Hot", "Icy"}
	nouns      = []string{"Wizard", "Ninja", "Pirate", "Cactus", "Panda", "Robot", "Alien", "Zombie", "Viking", "Ghost", "Penguin", "Badger", "Hamster", "Dragon", "Unicorn", "Gnome", "Troll", "Goblin", "Sprite", "Fairy"}
)

func generateProceduralName(id string) string {
	var hash uint32 = 0
	for i := 0; i < len(id); i++ {
		hash = uint32(id[i]) + (hash << 6) + (hash << 16) - hash
	}
	adj := adjectives[int(hash)%len(adjectives)]
	noun := nouns[int(hash/uint32(len(adjectives)))%len(nouns)]
	return fmt.Sprintf("%s%s", adj, noun)
}

func registerPlayerWithService(id, name string) {
	resp, err := http.PostForm("http://playerd:8080/players/"+id, url.Values{"username": {name}})
	if err != nil {
		log.Printf("Failed to register player %s: %v", id, err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	log.Printf("Player %s (%s) registered: %s", id, name, string(body))
}

var httpClient = &http.Client{
	Timeout: 5 * time.Second,
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
	UUID        string        `json:"uuid"`
	Rack        []string      `json:"rack"`
	TimeLeft    int           `json:"time_left"`
	IsActive    bool          `json:"is_active"`
	LetterValue int           `json:"letter_value,omitempty"`
	Results     []interface{} `json:"results,omitempty"`
}

type Gateway struct {
	clients      map[string]*Client
	gameClients  map[string][]string // GameUUID -> []ClientID
	clientGame   map[string]string   // ClientID -> GameUUID
	playerNames  map[string]string   // ClientID -> Nickname
	register     chan *Client
	unregister   chan *Client
	broadcast    chan Message // Global broadcast (e.g., chat)
	games        map[string]*GameState
	mu           sync.Mutex
	maxPlayers   int
	gameDuration int
}

func NewGateway() *Gateway {
	max := 10
	if m := os.Getenv("MAX_PLAYERS"); m != "" {
		fmt.Sscanf(m, "%d", &max)
	}

	duration := 30
	if d := os.Getenv("GAME_DURATION"); d != "" {
		fmt.Sscanf(d, "%d", &duration)
	}

	return &Gateway{
		clients:      make(map[string]*Client),
		gameClients:  make(map[string][]string),
		clientGame:   make(map[string]string),
		playerNames:  make(map[string]string),
		register:     make(chan *Client),
		unregister:   make(chan *Client),
		broadcast:    make(chan Message),
		games:        make(map[string]*GameState),
		maxPlayers:   max,
		gameDuration: duration,
	}
}

func (g *Gateway) StartGame() string {
	// Call tilemasters to get a rack and UUID
	resp, err := http.Post("http://tilemasters:3883/game", "application/json", nil)
	if err != nil {
		log.Printf("Failed to start game: %v", err)
		return ""
	}
	defer resp.Body.Close()

	var data struct {
		UUID        string   `json:"uuid"`
		Rack        []string `json:"rack"`
		LetterValue int      `json:"letter_value"`
	}
	json.NewDecoder(resp.Body).Decode(&data)

	game := &GameState{
		UUID:        data.UUID,
		Rack:        data.Rack,
		TimeLeft:    g.gameDuration,
		IsActive:    true,
		LetterValue: data.LetterValue,
	}

	g.mu.Lock()
	g.games[data.UUID] = game
	g.mu.Unlock()

	g.broadcastToGame(data.UUID, Message{
		Type:      "game_start",
		Payload:   game,
		Timestamp: time.Now().Unix(),
	})

	// Start timer ticker
	ticker := time.NewTicker(1 * time.Second)
	go func() {
		for range ticker.C {
			g.mu.Lock()
			gm, exists := g.games[data.UUID]
			if !exists || !gm.IsActive {
				ticker.Stop()
				g.mu.Unlock()
				return
			}
			gm.TimeLeft--
			timeLeft := gm.TimeLeft
			g.mu.Unlock()

			// Broadcast time update to all clients in this game
			g.broadcastToGame(data.UUID, Message{
				Type: "timer",
				Payload: map[string]interface{}{
					"time_left": timeLeft,
				},
				Timestamp: time.Now().Unix(),
			})

			if timeLeft <= 0 {
				ticker.Stop()
				g.EndGame(data.UUID)
				return
			}
		}
	}()
	return data.UUID
}

func (g *Gateway) broadcastToGame(gameUUID string, msg Message) {
	msgBytes, _ := json.Marshal(msg)
	g.mu.Lock()
	defer g.mu.Unlock()
	for _, clientID := range g.gameClients[gameUUID] {
		if client, ok := g.clients[clientID]; ok {
			client.Conn.WriteMessage(websocket.TextMessage, msgBytes)
		}
	}
}

func (g *Gateway) EndGame(gameUUID string) {
	g.mu.Lock()
	gm, exists := g.games[gameUUID]
	if !exists || !gm.IsActive {
		g.mu.Unlock()
		return
	}
	gm.IsActive = false
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

	g.broadcastToGame(gameUUID, Message{
		Type: "game_over",
		Payload: map[string]interface{}{
			"results": results,
			"summary": summaryText,
		},
		Timestamp: time.Now().Unix(),
	})

	// Start a replacement game immediately if this was the last active one
	g.mu.Lock()
	activeCount := 0
	for _, gm := range g.games {
		if gm.IsActive {
			activeCount++
		}
	}
	if activeCount == 0 {
		g.mu.Unlock()
		g.StartGame()
	} else {
		g.mu.Unlock()
	}

	// Cleanup game after 30 seconds to allow results viewing
	time.AfterFunc(30*time.Second, func() {
		g.mu.Lock()
		delete(g.games, gameUUID)
		g.mu.Unlock()
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
				if gameUUID, ok := g.clientGame[client.ID]; ok {
					clients := g.gameClients[gameUUID]
					newClients := []string{}
					for _, c := range clients {
						if c != client.ID {
							newClients = append(newClients, c)
						}
					}
					g.gameClients[gameUUID] = newClients
					delete(g.clientGame, client.ID)
				}
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

func (g *Gateway) joinNextAvailableGame(clientID string) {
	g.mu.Lock()
	// Unregister from old game if any
	if oldUUID, ok := g.clientGame[clientID]; ok {
		clients := g.gameClients[oldUUID]
		newClients := []string{}
		for _, c := range clients {
			if c != clientID {
				newClients = append(newClients, c)
			}
		}
		g.gameClients[oldUUID] = newClients
	}

	var joinUUID string
	for uuid, gm := range g.games {
		if gm.IsActive && len(g.gameClients[uuid]) < g.maxPlayers {
			joinUUID = uuid
			break
		}
	}
	g.mu.Unlock()

	if joinUUID == "" {
		joinUUID = g.StartGame()
	}

	g.mu.Lock()
	g.clientGame[clientID] = joinUUID
	g.gameClients[joinUUID] = append(g.gameClients[joinUUID], clientID)
	gm := g.games[joinUUID]
	g.mu.Unlock()

	if gm != nil {
		stateBytes, _ := json.Marshal(Message{
			Type:      "game_start",
			Payload:   gm,
			Timestamp: time.Now().Unix(),
		})
		if client, ok := g.clients[clientID]; ok {
			client.Conn.WriteMessage(websocket.TextMessage, stateBytes)
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

	nickname := generateProceduralName(clientID)
	go registerPlayerWithService(clientID, nickname)

	client := &Client{ID: clientID, Conn: conn}
	g.register <- client

	// Store player name
	g.mu.Lock()
	g.playerNames[clientID] = nickname
	g.mu.Unlock()

	// Find available game or start new one
	g.mu.Lock()
	var joinUUID string
	for uuid, gm := range g.games {
		if gm.IsActive && len(g.gameClients[uuid]) < g.maxPlayers {
			joinUUID = uuid
			break
		}
	}
	g.mu.Unlock()

	if joinUUID == "" {
		joinUUID = g.StartGame()
	}

	g.mu.Lock()
	g.clientGame[clientID] = joinUUID
	g.gameClients[joinUUID] = append(g.gameClients[joinUUID], clientID)
	gm := g.games[joinUUID]

	// Send ID and Name to client
	idMsg, _ := json.Marshal(Message{
		Type:      "identity",
		Payload:   map[string]string{"id": clientID, "name": nickname},
		Timestamp: time.Now().Unix(),
	})
	client.Conn.WriteMessage(websocket.TextMessage, idMsg)

	if gm != nil && gm.IsActive {
		stateBytes, _ := json.Marshal(Message{
			Type:      "game_start",
			Payload:   gm,
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
		case "join":
			g.joinNextAvailableGame(clientID)
		case "chat":
			// Add player name to chat message
			g.mu.Lock()
			gameUUID := g.clientGame[clientID]
			playerName := g.playerNames[clientID]
			g.mu.Unlock()
			if gameUUID != "" {
				// Enhance message with player name
				enhancedMsg := msg
				if payload, ok := msg.Payload.(string); ok {
					enhancedMsg.Payload = map[string]interface{}{
						"text":       payload,
						"senderName": playerName,
					}
				}
				g.broadcastToGame(gameUUID, enhancedMsg)
			}
		case "play":
			g.mu.Lock()
			gameUUID := g.clientGame[clientID]
			gm, exists := g.games[gameUUID]
			isActive := exists && gm.IsActive
			playerName := g.playerNames[clientID]
			g.mu.Unlock()

			if !isActive {
				continue
			}

			// Forward to Tilemasters service
			word := msg.Payload.(map[string]interface{})["word"].(string)
			playURL := fmt.Sprintf("http://tilemasters:3883/game/%s/play/%s", gameUUID, word)
			req, _ := http.NewRequest("GET", playURL, nil)
			req.Header.Set("Authorization", clientID)

			resp, err := httpClient.Do(req)
			if err == nil {
				defer resp.Body.Close()
				var result map[string]interface{}
				json.NewDecoder(resp.Body).Decode(&result)

				if _, hasError := result["error"]; !hasError {
					// Merge score and player name into original payload
					payload := msg.Payload.(map[string]interface{})
					if score, ok := result["score"]; ok {
						payload["score"] = score
					}
					payload["word"] = word
					payload["playerName"] = playerName
					msg.Payload = payload
					g.broadcastToGame(gameUUID, msg)
				} else {
					// Send error back to sender
					errMsg, _ := json.Marshal(Message{
						Type:      "error",
						Payload:   result["error"],
						Timestamp: time.Now().Unix(),
					})
					conn.WriteMessage(websocket.TextMessage, errMsg)
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
		// Just ensure at least one game is started if none exist
		gateway.mu.Lock()
		if len(gateway.games) == 0 {
			gateway.mu.Unlock()
			gateway.StartGame()
		} else {
			gateway.mu.Unlock()
		}
	})

	http.Handle("/ws", gateway)
	fmt.Println("GatewayD starting on :8081...")
	if err := http.ListenAndServe(":8081", nil); err != nil {
		log.Fatal("ListenAndServe:", err)
	}
}
