import { useState, useEffect } from 'react'
import TileRow from './components/TileRow'
import Timer from './components/Timer'
import Chat from './components/Chat'
import PlayByPlay from './components/PlayByPlay'
import Results from './components/Results'
import Leaderboard from './components/Leaderboard'
import DraggablePanel from './components/DraggablePanel'
import './App.css'

function App() {
    const [rack, setRack] = useState([])
    const [guess, setGuess] = useState(Array(7).fill(''))
    const [timeLeft, setTimeLeft] = useState(0)
    const [plays, setPlays] = useState([])
    const [messages, setMessages] = useState([])
    const [ws, setWs] = useState(null)
    const [playerId, setPlayerId] = useState(null)
    const [results, setResults] = useState(null)
    const [leaderboard, setLeaderboard] = useState([])

    const fetchLeaderboard = async () => {
        try {
            const resp = await fetch('http://localhost:8080/players/leaderboard');
            const data = await resp.json();
            setLeaderboard(Array.isArray(data) ? data : []);
        } catch (err) {
            console.error('Failed to fetch leaderboard:', err);
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
        fetchLeaderboard();

        const socket = new WebSocket(`ws://localhost:8081/ws?id=${id}`);

        socket.onopen = () => {
            console.log('Connected to gateway');
            setWs(socket);
        };

        socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'chat') {
                setMessages(prev => [...prev, {
                    sender: data.sender,
                    text: data.payload,
                    timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                }]);
            } else if (data.type === 'play') {
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
            } else if (data.type === 'game_start') {
                setRack(data.payload.rack);
                setTimeLeft(data.payload.time_left);
                setResults(null);
                setPlays([]);
                setGuess(Array(7).fill(''));
            } else if (data.type === 'game_over') {
                setResults(data.payload);
                fetchLeaderboard();
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

    const handleInputChange = (index, value) => {
        const newGuess = [...guess];
        newGuess[index] = value.toUpperCase().slice(-1);
        setGuess(newGuess);

        // Auto-focus next input
        if (value && index < 6) {
            document.getElementById(`input-${index + 1}`).focus();
        }
    };

    const handleKeyDown = (index, e) => {
        if (e.key === 'Backspace' && !guess[index] && index > 0) {
            document.getElementById(`input-${index - 1}`).focus();
        }
    };

    const submitWord = () => {
        const word = guess.join('');
        if (word.length === 0 || !ws) return;

        const score = word.length * 2; // Simple mock score
        ws.send(JSON.stringify({
            type: 'play',
            payload: { word, score }
        }));

        setGuess(Array(7).fill(''));
        document.getElementById('input-0').focus();
    };

    const sendMessage = (text) => {
        if (ws) {
            ws.send(JSON.stringify({
                type: 'chat',
                payload: text
            }));
        }
    };

    return (
        <div className="game-container">
            <header>
                <h1>wordw<span className="splat">💥</span>nk</h1>
            </header>

            <main className="game-area">
                <div className="center-panel">
                    <div className="rack-container">
                        <TileRow letters={rack} />
                        <Timer seconds={timeLeft} total={60} />
                    </div>

                    <div className="input-row">
                        {guess.map((letter, i) => (
                            <input
                                key={i}
                                id={`input-${i}`}
                                type="text"
                                value={letter}
                                onChange={(e) => handleInputChange(i, e.target.value)}
                                onKeyDown={(e) => handleKeyDown(i, e)}
                                maxLength={1}
                                className="tile-input"
                            />
                        ))}
                    </div>

                    <button className="submit-btn" onClick={submitWord}>
                        SUBMIT WORD!
                    </button>
                </div>

            </main>

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
        </div>
    )
}

export default App
