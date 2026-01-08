import { useState, useEffect, useRef } from 'react'
import Tile from './components/Tile'
import Timer from './components/Timer'
import Chat from './components/Chat'
import PlayByPlay from './components/PlayByPlay'
import Results from './components/Results'
import Leaderboard from './components/Leaderboard'
import DraggablePanel from './components/DraggablePanel'
import useSound from './hooks/useSound'
import './App.css'
import './LoadingModal.css'
import './JumbleButton.css'

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
    const [connectionError, setConnectionError] = useState(null)
    const [blankChoice, setBlankChoice] = useState(null) // { slotIndex, tileId }
    const [letterValue, setLetterValue] = useState(0) // Fixed score if mode is on
    const rackRef = useRef([]);
    const guessRef = useRef([]);
    const { play, startAmbience, toggleMute, isMuted } = useSound();
    const [playerNames, setPlayerNames] = useState({}); // Map playerID -> nickname
    const autoSubmittedRef = useRef(false);

    useEffect(() => {
        rackRef.current = rack;
    }, [rack]);

    useEffect(() => {
        guessRef.current = guess;
    }, [guess]);

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
            setConnectionError(null);
        };

        socket.onerror = (error) => {
            console.error('WebSocket error:', error);
            setConnectionError('Failed to connect to game server');
            setIsConnecting(false);
        };

        socket.onclose = () => {
            console.log('Disconnected from gateway');
            setWs(null);
            setIsConnecting(true);
            setConnectionError(null);
        };

        // Connection timeout - if not connected in 10 seconds, show error
        const connectionTimeout = setTimeout(() => {
            if (!socket || socket.readyState !== WebSocket.OPEN) {
                console.error('Connection timeout');
                setConnectionError('Connection timeout - please refresh the page');
                setIsConnecting(false);
                socket.close();
            }
        }, 10000);

        socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            console.log('WS MESSAGE RECEIVED:', data);
            if (data.type === 'chat') {
                console.log('Processing chat message:', data.payload);
                const text = typeof data.payload === 'string' ? data.payload : data.payload.text;
                const senderName = typeof data.payload === 'object' ? data.payload.senderName : playerNames[data.sender];
                setMessages(prev => [...prev, {
                    sender: data.sender,
                    senderName: senderName || data.sender,
                    text: text,
                    timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                }]);
            } else if (data.type === 'identity') {
                console.log('Received identity:', data.payload);
                setNickname(data.payload.name);
                setPlayerNames(prev => ({
                    ...prev,
                    [data.payload.id]: data.payload.name
                }));
            } else if (data.type === 'play') {
                console.log('Processing play message:', data.payload);
                const play = {
                    player: data.sender,
                    playerName: data.payload.playerName || playerNames[data.sender] || data.sender,
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
                setLetterValue(data.payload.letter_value || 0);
                setResults(null);
                setPlays([]);
                setGuess(Array(7).fill(null));
                setIsLocked(false);
                setFeedback({ text: '', type: '' });
                autoSubmittedRef.current = false; // Reset for new game
                startAmbience(); // Start background loop
            } else if (data.type === 'timer') {
                // Keep timer in sync with server
                if (data.payload && data.payload.time_left !== undefined) {
                    setTimeLeft(data.payload.time_left);
                }
            } else if (data.type === 'game_over') {
                setResults(data.payload);
                fetchLeaderboard();
                setIsLocked(false);
                play('bigsplat'); // Game end explosion
            }
        };

        return () => {
            clearTimeout(connectionTimeout);
            socket.close();
        };
    }, []);

    // Persistent state for identity
    const [nickname, setNickname] = useState("")

    useEffect(() => {
        if (timeLeft > 0) {
            const timer = setInterval(() => {
                setTimeLeft(prev => Math.max(0, prev - 1));
            }, 1000);
            return () => clearInterval(timer);
        }
    }, [timeLeft]);

    // Auto-submit word when timer hits 0
    useEffect(() => {
        if (timeLeft <= 0 && !isLocked && !autoSubmittedRef.current && guess.some(g => g !== null)) {
            // Build word from guess slots
            const word = guess.map(g => g ? g.char : '').join('').toUpperCase();
            if (word.length > 0 && ws && ws.readyState === WebSocket.OPEN) {
                console.log('Auto-submitting word at timer end:', word);
                autoSubmittedRef.current = true;
                // Inline submission to avoid circular dependency
                const msg = JSON.stringify({
                    type: 'play',
                    payload: { word }
                });
                ws.send(msg);
            }
        }
    }, [timeLeft, isLocked, guess, ws]);

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
        play('placement'); // Tile placed sound
    };

    const jumbleRack = () => {
        if (isLocked || timeLeft === 0) return;
        // Fisher-Yates shuffle
        setRack(prev => {
            const shuffled = [...prev];
            for (let i = shuffled.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
            }
            return shuffled;
        });
    };

    const clearGuess = () => {
        if (isLocked || timeLeft === 0) return;
        // Return all tiles from guess to rack
        const tilesToReturn = guess.filter(slot => slot !== null).map(slot => ({
            id: slot.id,
            letter: slot.originalLetter || slot.char.toUpperCase()
        }));
        setRack(prev => [...prev, ...tilesToReturn]);
        setGuess(Array(7).fill(null));
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
            play('placement'); // Tile placed sound
            return newGuess;
        });
    };

    const returnToRack = (slotIndex) => {
        if (isLocked || timeLeft === 0) return;

        setGuess(currentGuess => {
            // If slotIndex is not provided, find the last filled slot
            const targetIndex = slotIndex !== undefined ? slotIndex :
                [...currentGuess].reverse().findIndex(g => g !== null);

            const actualIndex = slotIndex !== undefined ? slotIndex :
                (targetIndex === -1 ? -1 : 6 - targetIndex);

            if (actualIndex === -1) return currentGuess;

            const played = currentGuess[actualIndex];
            if (!played) return currentGuess;

            const newGuess = [...currentGuess];
            newGuess[actualIndex] = null;
            setRack(prev => [...prev, { id: played.id, letter: played.originalLetter || played.char }]);
            return newGuess;
        });
    };

    const handleGlobalKeyDown = (e) => {
        // Ignore if typing in an input (like chat) or results is open
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
        if (isLocked || timeLeft === 0 || results) return;

        if (e.key === 'Backspace') {
            e.preventDefault();
            returnToRack();
        } else if (e.key === 'Enter') {
            e.preventDefault();
            submitWord();
        } else if (e.key.length === 1 && /[a-zA-Z]/.test(e.key)) {
            e.preventDefault();
            const char = e.key.toUpperCase();

            const currentRack = rackRef.current;
            const currentGuess = guessRef.current;

            // Priority 1: Match exact letter in rack
            const exactTile = currentRack.find(t => t.letter === char);
            if (exactTile) {
                moveTileToGuess(exactTile);
            } else {
                // Priority 2: Use blank if available
                const blankTile = currentRack.find(t => t.letter === '_');
                if (blankTile) {
                    const emptyIndex = currentGuess.findIndex(g => g === null);
                    if (emptyIndex !== -1) {
                        playTile(blankTile.id, char, emptyIndex);
                    }
                } else {
                    // No matching tile available
                    play('buzzer');
                }
            }
        }
    };

    useEffect(() => {
        window.addEventListener('keydown', handleGlobalKeyDown);
        return () => window.removeEventListener('keydown', handleGlobalKeyDown);
    }, [rack, guess, isLocked, timeLeft, results]);

    const joinGame = () => {
        setResults(null);
        if (ws) {
            ws.send(JSON.stringify({ type: 'join' }));
        }
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
                <div className="header-content">
                    <h1>wordw<span className="splat">💥</span>nk</h1>
                    {nickname && <div className="user-nickname">Playing as: <strong>{nickname}</strong></div>}
                </div>
                <button className="mute-btn" onClick={toggleMute} title={isMuted ? 'Unmute' : 'Mute'}>
                    {isMuted ? '🔇' : '🔊'}
                </button>
            </header>

            <main className="game-area">
                <div className="main-game-layout">
                    <div className="center-panel">
                        <div className="rack-section">
                            <div className="section-label">YOUR RACK (Click to Play)</div>
                            <div className="rack-container clickable">
                                {rack.map((tile) => (
                                    <div key={tile.id} onClick={() => moveTileToGuess(tile)}>
                                        <Tile letter={tile.letter} value={letterValue > 0 ? letterValue : undefined} />
                                    </div>
                                ))}
                                {rack.length === 0 && <div className="empty-rack-msg">ALL TILES PLAYED!</div>}
                            </div>
                            <div className="rack-actions">
                                <button
                                    className="jumble-btn"
                                    onClick={jumbleRack}
                                    disabled={isLocked || timeLeft === 0 || rack.length === 0}
                                    title="Shuffle tiles"
                                >
                                    🔀 JUMBLE
                                </button>
                                <button
                                    className="clear-btn"
                                    onClick={clearGuess}
                                    disabled={isLocked || timeLeft === 0 || guess.every(g => g === null)}
                                    title="Clear all tiles from word"
                                >
                                    🧹 CLEAR
                                </button>
                            </div>
                        </div>

                        <div className="input-section">
                            <div className="section-label">YOUR WORD (Click to Remove)</div>
                            <div className="word-board">
                                {guess.map((slot, i) => {
                                    const isFirstEmpty = guess.findIndex(g => g === null) === i;
                                    return (
                                        <div
                                            key={i}
                                            className={`board-slot ${slot ? 'filled' : 'empty'} ${isFirstEmpty && !isLocked && timeLeft > 0 ? 'focused' : ''}`}
                                            onClick={() => slot && returnToRack(i)}
                                        >
                                            {slot ? (
                                                <Tile letter={slot.char} value={letterValue > 0 ? letterValue : undefined} />
                                            ) : (
                                                <div className="slot-placeholder"></div>
                                            )}
                                        </div>
                                    );
                                })}
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
                <PlayByPlay plays={plays} playerNames={playerNames} />
            </DraggablePanel>

            <DraggablePanel title="CHAT" id="chat" initialPos={{ x: window.innerWidth - 320, y: 380 }}>
                <Chat messages={messages} onSendMessage={sendMessage} playerNames={playerNames} />
            </DraggablePanel>

            {results && <Results data={results} onClose={joinGame} playerNames={playerNames} />}

            {(isConnecting || connectionError) && (
                <div className="loading-modal">
                    <div className="loading-card">
                        {connectionError ? (
                            <>
                                <div className="error-icon">⚠️</div>
                                <h2>CONNECTION ERROR</h2>
                                <p>{connectionError}</p>
                                <button className="reload-btn" onClick={() => window.location.reload()}>
                                    RELOAD PAGE
                                </button>
                            </>
                        ) : (
                            <>
                                <div className="loading-spinner"></div>
                                <h2>LOADING...</h2>
                                <p>Connecting to game server</p>
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    )
}

export default App
