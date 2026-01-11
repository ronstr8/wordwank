import { useState, useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
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
import Login from './components/Login'

function App() {
    const { t, i18n } = useTranslation()
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
    const { play, startAmbience, stopAmbience, toggleAmbience, toggleMute, isMuted, isAmbienceEnabled } = useSound();
    const [playerNames, setPlayerNames] = useState({}); // Map playerID -> nickname
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [isAuthChecking, setIsAuthChecking] = useState(true);
    const autoSubmittedRef = useRef(false);

    // Panel visibility with localStorage persistence
    const loadPanelVisibility = (panelName, defaultValue = false) => {
        try {
            const saved = localStorage.getItem(`panel_visible_${panelName}`);
            return saved !== null ? JSON.parse(saved) : defaultValue;
        } catch {
            return defaultValue;
        }
    };

    const savePanelVisibility = (panelName, visible) => {
        try {
            localStorage.setItem(`panel_visible_${panelName}`, JSON.stringify(visible));
        } catch (e) {
            console.error('Failed to save panel visibility:', e);
        }
    };

    const [leaderboardVisible, setLeaderboardVisible] = useState(() => loadPanelVisibility('leaderboard'));
    const [playByPlayVisible, setPlayByPlayVisible] = useState(() => loadPanelVisibility('playByPlay'));
    const [chatVisible, setChatVisible] = useState(() => loadPanelVisibility('chat'));

    // Save visibility states to localStorage when they change
    useEffect(() => {
        savePanelVisibility('leaderboard', leaderboardVisible);
    }, [leaderboardVisible]);

    useEffect(() => {
        savePanelVisibility('playByPlay', playByPlayVisible);
    }, [playByPlayVisible]);

    useEffect(() => {
        savePanelVisibility('chat', chatVisible);
    }, [chatVisible]);

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
            console.log('Leaderboard data fetched:', data);
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

    const checkAuth = async () => {
        try {
            const resp = await fetch('/auth/me');
            if (resp.ok) {
                const data = await resp.json();
                setPlayerId(data.id);
                playerIdRef.current = data.id;
                setNickname(data.nickname);
                if (data.language) i18n.changeLanguage(data.language);
                setIsAuthenticated(true);
                return data.id;
            }
        } catch (err) {
            console.error('Auth check failed:', err);
        } finally {
            setIsAuthChecking(false);
        }
        return null;
    };

    useEffect(() => {
        const init = async () => {
            await checkAuth();
            fetchLeaderboard();
        };
        init();
    }, []);

    useEffect(() => {
        if (!playerId) return;

        const isLocal = window.location.hostname === 'localhost';
        const wsHost = isLocal ? 'localhost:8081' : window.location.host;
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        let socket = null;
        let reconnectTimeout = null;

        const connect = () => {
            if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) return;

            console.log('Attempting to connect to gateway...');
            socket = new WebSocket(`${protocol}//${wsHost}/ws?id=${playerId}`);

            socket.onopen = () => {
                console.log('Connected to gateway - Player:', playerId);
                setWs(socket);
                setIsConnecting(false);
                setConnectionError(null);

                // Auto-join the active game
                socket.send(JSON.stringify({ type: 'join' }));
            };

            socket.onerror = (error) => {
                console.error('WebSocket error:', error);
            };

            socket.onclose = () => {
                console.log('Disconnected from gateway - will retry in 2s');
                setWs(null);
                setIsConnecting(true);
                reconnectTimeout = setTimeout(connect, 2000);
            };

            socket.onmessage = (event) => {
                const data = JSON.parse(event.data);
                if (data.type === 'chat') {
                    const text = typeof data.payload === 'string' ? data.payload : data.payload.text;
                    const senderName = typeof data.payload === 'object' ? data.payload.senderName : playerNames[data.sender];
                    setMessages(prev => [...prev, {
                        sender: data.sender,
                        senderName: senderName || data.sender,
                        text: text,
                        timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                    }]);
                } else if (data.type === 'identity') {
                    setNickname(data.payload.name);
                    if (data.payload.language) {
                        i18n.changeLanguage(data.payload.language);
                    }
                    setPlayerNames(prev => ({
                        ...prev,
                        [data.payload.id]: data.payload.name
                    }));
                } else if (data.type === 'game_start') {
                    const newRack = data.payload.rack.map((letter, idx) => ({
                        id: `tile-${idx}-${Date.now()}`,
                        letter,
                        position: idx,
                        isUsed: false
                    }));
                    setRack(newRack);
                    setTimeLeft(data.payload.time_left);
                    setLetterValue(data.payload.letter_values || 0);
                    setResults(null);
                    setPlays([]);
                    setGuess(Array(7).fill(null));
                    setIsLocked(false);
                    setFeedback({ text: '', type: '' });
                    autoSubmittedRef.current = false; // Reset for new game
                    startAmbience(); // Start background loop
                    fetchLeaderboard();
                } else if (data.type === 'timer') {
                    if (data.payload && data.payload.time_left !== undefined) {
                        const newTime = Math.max(0, data.payload.time_left);
                        setTimeLeft(newTime);
                    }
                } else if (data.type === 'play') {
                    const playObj = {
                        player: data.sender,
                        playerName: data.payload.playerName || playerNames[data.sender] || data.sender,
                        word: data.payload.word,
                        score: data.payload.score,
                        timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                    };
                    setPlays(prev => {
                        const filtered = prev.filter(p => p.player !== data.sender);
                        return [playObj, ...filtered];
                    });
                    if (data.sender === playerIdRef.current) {
                        setFeedback({ text: t('app.accepted'), type: 'success' });
                        setIsLocked(true);
                        setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                    }
                } else if (data.type === 'error') {
                    setFeedback({ text: data.payload, type: 'error' });
                    setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                } else if (data.type === 'play_result') {
                    setPlays(prev => [...prev, {
                        player: data.sender,
                        playerName: data.payload.playerName || playerNames[data.sender] || data.sender,
                        word: data.payload.word,
                        score: data.payload.score,
                        id: Date.now()
                    }]);
                } else if (data.type === 'game_end') {
                    const resultsData = {
                        results: data.payload.plays || [],
                        summary: (data.payload.plays && data.payload.plays.length > 0) ? t('results.round_over') : t('results.no_plays_round')
                    };
                    if (resultsData.results.length > 0 && data.payload.definition) {
                        resultsData.results[0].definition = data.payload.definition;
                    }
                    setResults(resultsData);
                    setIsLocked(true);
                    play('game_over');
                    fetchLeaderboard();
                }
            };
        };

        connect();

        const handleVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                connect();
            }
        };
        document.addEventListener('visibilitychange', handleVisibilityChange);

        return () => {
            document.removeEventListener('visibilitychange', handleVisibilityChange);
            if (socket) socket.close();
            if (reconnectTimeout) clearTimeout(reconnectTimeout);
        };
    }, [playerId]);

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
        if (timeLeft <= 0 && !isLocked && !autoSubmittedRef.current && guessRef.current.some(g => g !== null)) {
            // Build word from guess slots
            const word = guessRef.current.map(g => g ? g.char : '').join('').toUpperCase().trim();
            if (word.length > 0 && ws && ws.readyState === WebSocket.OPEN) {
                console.log('AUTO-SUBMITTING:', word);
                autoSubmittedRef.current = true;
                ws.send(JSON.stringify({ type: 'play', payload: { word } }));
            }
        }
    }, [timeLeft, isLocked, ws]);
    // Wait, if guess changes while timeLeft is 0, we might want to submit? No, usually it's at the transition.

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
        // Fisher-Yates shuffle positions only
        setRack(prev => {
            const shuffled = [...prev];
            for (let i = shuffled.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
            }
            // Update positions after shuffle
            return shuffled.map((tile, idx) => ({ ...tile, position: idx }));
        });
    };

    const clearGuess = () => {
        if (isLocked || timeLeft === 0) return;
        // Mark all tiles as unused
        setRack(prev => prev.map(tile => ({ ...tile, isUsed: false })));
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
        if (isLocked || timeLeft === 0 || tile.isUsed) return;

        setGuess(currentGuess => {
            const emptyIndex = currentGuess.findIndex(g => g === null);
            if (emptyIndex === -1) return currentGuess;

            if (tile.letter === '_') {
                setBlankChoice({ slotIndex: emptyIndex, tileId: tile.id });
                return currentGuess;
            }

            const newGuess = [...currentGuess];
            newGuess[emptyIndex] = { id: tile.id, char: tile.letter, originalLetter: tile.letter };
            // Mark tile as used instead of removing it
            setRack(prev => prev.map(t => t.id === tile.id ? { ...t, isUsed: true } : t));
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
            // Mark tile as unused instead of adding it back
            setRack(prev => prev.map(t => t.id === played.id ? { ...t, isUsed: false } : t));
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

            // Priority 1: Match exact letter in rack (that isn't already used)
            const exactTile = currentRack.find(t => t.letter === char && !t.isUsed);
            if (exactTile) {
                moveTileToGuess(exactTile);
            } else {
                // Priority 2: Use blank if available
                const blankTile = currentRack.find(t => t.letter === '_' && !t.isUsed);
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

    const handleLogout = async () => {
        try {
            await fetch('/auth/logout', { method: 'POST' });
            setIsAuthenticated(false);
            setPlayerId(null);
            setNickname("");
            setWs(null);
        } catch (err) {
            console.error('Logout failed:', err);
        }
    };

    const handleRegisterPasskey = async () => {
        try {
            const resp = await fetch('/auth/passkey/challenge');
            if (!resp.ok) throw new Error('Could not get challenge');
            const options = await resp.json();

            // Convert base64 to ArrayBuffer
            options.challenge = Uint8Array.from(atob(options.challenge), c => c.charCodeAt(0)).buffer;
            options.user.id = Uint8Array.from(options.user.id, c => c.charCodeAt(0)).buffer;

            if (options.excludeCredentials) {
                options.excludeCredentials = options.excludeCredentials.map(c => ({
                    ...c,
                    id: Uint8Array.from(atob(c.id), ch => ch.charCodeAt(0)).buffer
                }));
            }

            const credential = await navigator.credentials.create({
                publicKey: options
            });

            const verifyResp = await fetch('/auth/passkey/verify', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id: credential.id,
                    type: 'registration',
                    rawId: btoa(String.fromCharCode(...new Uint8Array(credential.rawId))),
                    response: {
                        attestationObject: btoa(String.fromCharCode(...new Uint8Array(credential.response.attestationObject))),
                        clientDataJSON: btoa(String.fromCharCode(...new Uint8Array(credential.response.clientDataJSON))),
                    }
                })
            });

            if (verifyResp.ok) {
                setFeedback({ text: t('auth.passkey_registered'), type: 'success' });
            } else {
                throw new Error('Verification failed');
            }
        } catch (err) {
            console.error('Passkey registration failed:', err);
            setFeedback({ text: err.name === 'NotAllowedError' ? 'Registration cancelled' : err.message, type: 'error' });
        } finally {
            setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
        }
    };

    if (isAuthChecking) {
        return (
            <div className="loading-modal">
                <div className="loading-card">
                    <div className="loading-spinner"></div>
                    <h2>{t('app.loading')}</h2>
                    <p>{t('auth.logging_in')}</p>
                </div>
            </div>
        );
    }

    if (!isAuthenticated) {
        return <Login onLoginSuccess={() => checkAuth()} />;
    }

    return (
        <div className="game-container">
            <header>
                <div className="header-content">
                    <h1 style={{ whiteSpace: 'nowrap' }}>wordw<span className="splat">💥</span>nk</h1>
                    {nickname && <div className="user-nickname">{t('app.playing_as')}: <strong>{nickname}</strong></div>}
                </div>
                <div className="header-toggles">
                    <button
                        className={`panel-toggle ${leaderboardVisible ? 'active' : ''}`}
                        onClick={() => setLeaderboardVisible(!leaderboardVisible)}
                    >
                        Leaderboard
                    </button>
                    <button
                        className={`panel-toggle ${playByPlayVisible ? 'active' : ''}`}
                        onClick={() => setPlayByPlayVisible(!playByPlayVisible)}
                    >
                        Play-by-Play
                    </button>
                    <button
                        className={`panel-toggle ${chatVisible ? 'active' : ''}`}
                        onClick={() => setChatVisible(!chatVisible)}
                    >
                        Chat
                    </button>
                </div>
                <div className="header-actions">
                    {/* Group 1: Authentication */}
                    <div className="button-group">
                        <button className="header-btn" onClick={handleRegisterPasskey} title={t('auth.register_passkey')}>
                            🔑
                        </button>
                        <button className="header-btn logout" onClick={handleLogout} title={t('auth.logout')}>
                            🚪
                        </button>
                    </div>

                    {/* Group 2: Audio Controls */}
                    <div className="button-group">
                        <button className="header-btn" onClick={toggleAmbience} title={isAmbienceEnabled ? 'Turn off background music' : 'Turn on background music'}>
                            {isAmbienceEnabled ? '🎵' : '🔇'}
                        </button>
                        <button className="header-btn" onClick={toggleMute} title={isMuted ? 'Unmute all sounds' : 'Mute all sounds'}>
                            {isMuted ? '🔈' : '🔊'}
                        </button>
                    </div>

                    {/* Group 3: Language Selection */}
                    <div className="button-group">
                        <select
                            className="lang-select"
                            value={i18n.language}
                            onChange={(e) => {
                                const newLang = e.target.value;
                                i18n.changeLanguage(newLang);
                                if (ws && ws.readyState === WebSocket.OPEN) {
                                    ws.send(JSON.stringify({
                                        type: 'set_language',
                                        payload: { language: newLang }
                                    }));
                                }
                            }}
                        >
                            <option value="en">EN</option>
                            <option value="es">ES</option>
                        </select>
                    </div>
                </div>
            </header>

            <main className="game-area">
                <div className="main-game-layout">
                    <div className="center-panel">
                        <div className="rack-section">
                            <div className="section-label">{t('app.rack_label')}</div>
                            <div className="rack-container clickable">
                                {[0, 1, 2, 3, 4, 5, 6].map(position => {
                                    const tile = rack.find(t => t.position === position);
                                    if (!tile) return <div key={position} className="rack-slot empty" />;

                                    return (
                                        <div
                                            key={tile.id}
                                            className={`rack-slot ${tile.isUsed ? 'used' : ''}`}
                                            onClick={() => !tile.isUsed && moveTileToGuess(tile)}
                                        >
                                            <Tile
                                                letter={tile.letter}
                                                value={typeof letterValue === 'object' ? letterValue[tile.letter] : (letterValue > 0 ? letterValue : undefined)}
                                                disabled={tile.isUsed}
                                            />
                                        </div>
                                    );
                                })}
                                {rack.length === 0 && <div className="empty-rack-msg">{t('app.empty_rack')}</div>}
                            </div>
                            <div className="rack-actions">
                                <button
                                    className="jumble-btn"
                                    onClick={jumbleRack}
                                    disabled={isLocked || timeLeft === 0 || rack.length === 0}
                                    title={t('app.jumble')}
                                >
                                    {t('app.jumble')}
                                </button>
                                <button
                                    className="clear-btn"
                                    onClick={clearGuess}
                                    disabled={isLocked || timeLeft === 0 || guess.every(g => g === null)}
                                    title={t('app.clear')}
                                >
                                    {t('app.clear')}
                                </button>
                            </div>
                        </div>

                        <div className="input-section">
                            <div className="section-label">{t('app.word_label')}</div>
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
                                                <Tile
                                                    letter={slot.char}
                                                    value={typeof letterValue === 'object' ? letterValue[slot.originalLetter || slot.char.toUpperCase()] : (letterValue > 0 ? letterValue : undefined)}
                                                />
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
                                    {t('app.submit')}
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
                        <h3>{t('app.select_blank')}</h3>
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
                        <button className="cancel-btn" onClick={() => setBlankChoice(null)}>{t('app.cancel')}</button>
                    </div>
                </div>
            )}

            {leaderboardVisible && (
                <DraggablePanel
                    title={t('app.leaderboard')}
                    id="leaderboard"
                    initialPos={{ x: 20, y: 100 }}
                    initialSize={{ width: 220, height: 200 }}
                    onClose={() => setLeaderboardVisible(false)}
                    storageKey="leaderboard"
                >
                    <Leaderboard players={leaderboard} />
                </DraggablePanel>
            )}

            {playByPlayVisible && (
                <DraggablePanel
                    title={t('app.play_by_play')}
                    id="plays"
                    initialPos={{ x: window.innerWidth - 240, y: 100 }}
                    initialSize={{ width: 220, height: 200 }}
                    onClose={() => setPlayByPlayVisible(false)}
                    storageKey="playByPlay"
                >
                    <PlayByPlay plays={plays} playerNames={playerNames} />
                </DraggablePanel>
            )}

            {chatVisible && (
                <DraggablePanel
                    title={t('app.chat')}
                    id="chat"
                    initialPos={{ x: window.innerWidth - 320, y: 380 }}
                    initialSize={{ width: 300, height: 350 }}
                    onClose={() => setChatVisible(false)}
                    storageKey="chat"
                >
                    <Chat messages={messages} onSendMessage={sendMessage} playerNames={playerNames} />
                </DraggablePanel>
            )}

            {results && <Results data={results} onClose={joinGame} playerNames={playerNames} />}

            {(isConnecting || connectionError || (rack.length === 0 && !results)) && (
                <div className="loading-modal">
                    <div className="loading-card">
                        {connectionError ? (
                            <>
                                <div className="error-icon">⚠️</div>
                                <h2>{t('app.connection_error')}</h2>
                                <p>{connectionError}</p>
                                <button className="reload-btn" onClick={() => window.location.reload()}>
                                    {t('app.reload')}
                                </button>
                            </>
                        ) : (
                            <>
                                <div className="loading-spinner"></div>
                                <h2>{t('app.loading')}</h2>
                                <p>{rack.length === 0 && !isConnecting ? t('app.waiting_next_game') : t('app.connecting')}</p>
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    )
}

export default App
