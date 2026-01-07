import { useState, useEffect, useRef } from 'react'
import Tile from './components/Tile'
import Timer from './components/Timer'
import Chat from './components/Chat'
import PlayByPlay from './components/PlayByPlay'
import Results from './components/Results'
import Leaderboard from './components/Leaderboard'
import DraggablePanel from './components/DraggablePanel'
import './App.css'

function App() {
    const [rack, setRack] = useState([]) // Array of { id, letter }
    const [guess, setGuess] = useState(Array(7).fill(null)) // Array of { id, char } or null
    const [timeLeft, setTimeLeft] = useState(0)
    const playerIdRef = useRef(null)
    const [plays, setPlays] = useState([])
    const [messages, setMessages] = useState([])
    const [ws, setWs] = useState(null)
    const [playerId, setPlayerId] = useState(null)
    const [results, setResults] = useState(null)
    const [leaderboard, setLeaderboard] = useState([])
    const [feedback, setFeedback] = useState({ text: '', type: '' })
    const [isLocked, setIsLocked] = useState(false)
    const [isConnecting, setIsConnecting] = useState(true)
    const [blankChoice, setBlankChoice] = useState(null) // { slotIndex, tileId }

    const fetchLeaderboard = async () => {
        try {
            const isLocal = window.location.hostname === 'localhost';
            const apiPath = isLocal ? 'http://localhost:8080/players/leaderboard' : '/players/leaderboard';
            const resp = await fetch(apiPath);
            if (!resp.ok) throw new Error(`HTTP error! status: ${resp.status}`);
            const data = await resp.json();
            setLeaderboard(Array.isArray(data) ? data : []);
        } catch (err) {
            console.error('Failed to fetch leaderboard:', err);
            setLeaderboard([]);
        }
    };

    const getCookie = (name) => {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) return parts.pop().split(';').shift();
    };

    const setCookie = (name, value, days = 7) => {
        const date = new Date();
        date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
        document.cookie = `${name}=${value};expires=${date.toUTCString()};path=/`;
    };

    useEffect(() => {
        let id = getCookie('wankID');
        if (!id) {
            id = Math.random().toString(36).substring(2, 15);
            setCookie('wankID', id);
        }
        setPlayerId(id);
        playerIdRef.current = id;
        fetchLeaderboard();

        const isLocal = window.location.hostname === 'localhost';
        const wsHost = isLocal ? 'localhost:8081' : window.location.host;
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const socket = new WebSocket(`${protocol}//${wsHost}/ws?id=${id}`);

        socket.onopen = () => {
            console.log('Connected to gateway - Player:', id);
            setWs(socket);
            setIsConnecting(false);
        };

        socket.onclose = () => {
            console.log('Disconnected from gateway');
            setWs(null);
            setIsConnecting(true);
        };

        socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            console.log('WS MESSAGE RECEIVED:', data);
            if (data.type === 'chat') {
                console.log('Processing chat message:', data.payload);
                setMessages(prev => [...prev, {
                    sender: data.sender,
                    text: data.payload,
                    timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                }]);
            } else if (data.type === 'play') {
                console.log('Processing play message:', data.payload);
                const play = {
                    player: data.sender,
                    word: data.payload.word,
                    score: data.payload.score,
                    timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                };
                setPlays(prev => {
                    const filtered = prev.filter(p => p.player !== data.sender);
                    return [play, ...filtered];
                });
                if (data.sender === playerIdRef.current) {
                    setFeedback({ text: 'ACCEPTED!', type: 'success' });
                    setIsLocked(true);
                    setTimeout(() => setFeedback({ text: '', type: '' }), 15000);
                }
            } else if (data.type === 'error') {
                setFeedback({ text: data.payload, type: 'error' });
                setTimeout(() => setFeedback({ text: '', type: '' }), 15000);
            } else if (data.type === 'game_start') {
                const newRack = data.payload.rack.map((letter, index) => ({
                    id: `tile-${index}-${Date.now()}`,
                    letter
                }));
                setRack(newRack);
                setTimeLeft(data.payload.time_left);
                setResults(null);
                setPlays([]);
                setGuess(Array(7).fill(null));
                setIsLocked(false);
                setFeedback({ text: '', type: '' });
            } else if (data.type === 'game_over') {
                setResults(data.payload);
                fetchLeaderboard();
                setIsLocked(false);
            }
        };

        return () => socket.close();
    }, []);

    useEffect(() => {
        if (timeLeft > 0) {
            const timer = setInterval(() => {
                setTimeLeft(prev => Math.max(0, prev - 1));
            }, 1000);
            return () => clearInterval(timer);
        }
    }, [timeLeft]);

    const handleTileClick = (tile, source) => {
        if (isLocked || timeLeft === 0) return;

        if (source === 'rack') {
            // Find first empty slot
            const emptyIndex = guess.findIndex(g => g === null);
            if (emptyIndex !== -1) {
                if (tile.letter === '_') {
                    setBlankChoice({ slotIndex: emptyIndex, tileId: tile.id });
                } else {
                    const newGuess = [...guess];
                    newGuess[emptyIndex] = { id: tile.id, char: tile.letter };
                    setGuess(newGuess);
                    setRack(prev => prev.filter(t => t.id !== tile.id));
                }
            }
        } else {
            // Return to rack
            const slotIndex = source;
            const playedTile = guess[slotIndex];
            const originalLetter = rack.find(t => t.id === playedTile.id)?.letter || playedTile.char; // Approximation

            setRack(prev => [...prev, { id: playedTile.id, letter: playedTile.id.includes('_') ? '_' : playedTile.char }]); // This is complex, let's simplify
        }
    };

    const playTile = (tileId, letter, slotIndex) => {
        const tile = rack.find(t => t.id === tileId);
        if (!tile) return;

        const newGuess = [...guess];
        // Convert to lowercase to indicate it's a blank (0 points)
        newGuess[slotIndex] = { id: tileId, char: letter.toLowerCase(), originalLetter: '_' };
        setGuess(newGuess);
        setRack(prev => prev.filter(t => t.id !== tileId));
        setBlankChoice(null);
    };

    const returnTile = (slotIndex) => {
        if (isLocked || timeLeft === 0) return;
        const tile = guess[slotIndex];
        if (!tile) return;

        // We need to know the original letter. Let's store it in the guess object.
        // Actually, just looking at 'char' works, but for blanks we need to know it was a blank.
        // Let's assume for now tiles have an 'isBlank' or similar. 
        // Better: store original letter in guess object.
    };

    const moveTileToGuess = (tile) => {
        if (isLocked || timeLeft === 0) return;

        setGuess(currentGuess => {
            const emptyIndex = currentGuess.findIndex(g => g === null);
            if (emptyIndex === -1) return currentGuess;

            if (tile.letter === '_') {
                setBlankChoice({ slotIndex: emptyIndex, tileId: tile.id });
                return currentGuess;
            }

            const newGuess = [...currentGuess];
            newGuess[emptyIndex] = { id: tile.id, char: tile.letter, originalLetter: tile.letter };
            setRack(prev => prev.filter(t => t.id !== tile.id));
            return newGuess;
        });
    };

    const returnToRack = (slotIndex) => {
        if (isLocked || timeLeft === 0) return;

        setGuess(currentGuess => {
            const played = currentGuess[slotIndex];
            if (!played) return currentGuess;

            const newGuess = [...currentGuess];
            newGuess[slotIndex] = null;
            setRack(prev => [...prev, { id: played.id, letter: played.originalLetter || played.char }]);
            return newGuess;
        });
    };

    const submitWord = () => {
        const word = guess.map(g => g ? g.char : '').join('').toUpperCase().trim();
        console.log('Submitting word attempt:', word);
        if (word.length === 0 || !ws) {
            console.log('Submission failed: word empty or WS null');
            return;
        }

        const msg = JSON.stringify({ type: 'play', payload: { word } });
        console.log('SENDING PLAY:', msg);
        ws.send(msg);
    };

    const sendMessage = (text) => {
        console.log('Chat message attempt:', text, 'WS Status:', ws?.readyState);
        if (ws) {
            const msg = JSON.stringify({
                type: 'chat',
                payload: text
            });
            console.log('SENDING CHAT:', msg);
            ws.send(msg);
        } else {
            console.log('Chat blocked: WS null');
        }
    };

    return (
        <div className="game-container">
            <header>
                <h1>wordw<span className="splat">💥</span>nk</h1>
            </header>

            <main className="game-area">
                <div className="main-game-layout">
                    <div className="center-panel">
                        <div className="rack-section">
                            <div className="section-label">YOUR RACK (Click to Play)</div>
                            <div className="rack-container clickable">
                                {rack.map((tile) => (
                                    <div key={tile.id} onClick={() => moveTileToGuess(tile)}>
                                        <Tile letter={tile.letter} />
                                    </div>
                                ))}
                                {rack.length === 0 && <div className="empty-rack-msg">ALL TILES PLAYED!</div>}
                            </div>
                        </div>

                        <div className="input-section">
                            <div className="section-label">YOUR WORD (Click to Remove)</div>
                            <div className="word-board">
                                {guess.map((slot, i) => (
                                    <div
                                        key={i}
                                        className={`board-slot ${slot ? 'filled' : 'empty'}`}
                                        onClick={() => slot && returnToRack(i)}
                                    >
                                        {slot ? (
                                            <Tile letter={slot.char} />
                                        ) : (
                                            <div className="slot-placeholder"></div>
                                        )}
                                    </div>
                                ))}
                            </div>
                            <div className="submit-container">
                                <button
                                    className="submit-btn"
                                    onClick={submitWord}
                                    disabled={isLocked || timeLeft === 0 || guess.every(g => g === null)}
                                >
                                    SUBMIT WORD!
                                </button>
                                {feedback.text && (
                                    <div className={`feedback-label ${feedback.type} visible`}>
                                        {feedback.text}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    <div className="timer-sidebar">
                        <Timer seconds={timeLeft} total={60} />
                    </div>
                </div>
            </main>

            {blankChoice && (
                <div className="blank-modal-overlay">
                    <div className="blank-modal">
                        <h3>SELECT LETTER FOR BLANK</h3>
                        <div className="letter-grid">
                            {"ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map(l => (
                                <button
                                    key={l}
                                    className="letter-btn"
                                    onClick={() => playTile(blankChoice.tileId, l, blankChoice.slotIndex)}
                                >
                                    {l}
                                </button>
                            ))}
                        </div>
                        <button className="cancel-btn" onClick={() => setBlankChoice(null)}>CANCEL</button>
                    </div>
                </div>
            )}

            <DraggablePanel title="LEADERBOARD" id="leaderboard" initialPos={{ x: 20, y: 100 }}>
                <Leaderboard players={leaderboard} />
            </DraggablePanel>

            <DraggablePanel title="PLAY-BY-PLAY" id="plays" initialPos={{ x: window.innerWidth - 320, y: 100 }}>
                <PlayByPlay plays={plays} />
            </DraggablePanel>

            <DraggablePanel title="CHAT" id="chat" initialPos={{ x: window.innerWidth - 320, y: 380 }}>
                <Chat messages={messages} onSendMessage={sendMessage} />
            </DraggablePanel>

            {results && <Results data={results} />}

            {isConnecting && (
                <div className="loading-modal">
                    <div className="loading-card">
                        <div className="loading-spinner"></div>
                        <h2>CONNECTING TO ARKHAM...</h2>
                        <p>Establishing neural link with the gateway</p>
                    </div>
                </div>
            )}
        </div>
    )
}

export default App
