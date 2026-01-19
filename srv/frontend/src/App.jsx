import { useState, useEffect, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import Tile from './components/Tile'
import Timer from './components/Timer'
import Chat from './components/Chat'
import Results from './components/Results'
import Leaderboard from './components/Leaderboard'
import DraggablePanel from './components/DraggablePanel'
import useSound from './hooks/useSound'
import './App.css'
import './LoadingModal.css'
import './JumbleButton.css'
import Login from './components/Login'
import PlayerStats from './components/PlayerStats'
import PasskeySetup from './components/PasskeySetup'
import Sidebar from './components/Sidebar'
import { CONFIG } from './config'
import './components/Toast.css'

function App() {
    const { t, i18n } = useTranslation()
    const [rack, setRack] = useState([]) // Array of { id, letter }
    const [guess, setGuess] = useState(Array(8).fill(null)) // Array of { id, char } or null
    const [timeLeft, setTimeLeft] = useState(0)
    const [totalTime, setTotalTime] = useState(30) // Default to 30, updated on game_start
    const playerIdRef = useRef(null)
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
    const [showRules, setShowRules] = useState(false);
    const [showDonations, setShowDonations] = useState(false);
    const [showStats, setShowStats] = useState(false); // Assuming this is for a future stats panel
    const [tileConfig, setTileConfig] = useState({ tiles: {}, unicorns: {} });
    const [gameId, setGameId] = useState(null); // Added gameId state
    const rackRef = useRef([]);
    const guessRef = useRef([]);
    const { play, startAmbience, stopAmbience, toggleAmbience, toggleMute, isMuted, isAmbienceEnabled } = useSound();
    const [playerNames, setPlayerNames] = useState({}); // Map playerID -> nickname
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [isAuthChecking, setIsAuthChecking] = useState(true);
    const [hasPasskey, setHasPasskey] = useState(false);
    const autoSubmittedRef = useRef(false);
    const [isFocusMode, setIsFocusMode] = useState(() => {
        try {
            const saved = localStorage.getItem('focus_mode');
            return saved !== null ? JSON.parse(saved) : false;
        } catch {
            return false;
        }
    });
    const [sidebarOpen, setSidebarOpen] = useState(false);
    const [toasts, setToasts] = useState([]);

    useEffect(() => {
        localStorage.setItem('focus_mode', JSON.stringify(isFocusMode));
    }, [isFocusMode]);

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
    const [chatVisible, setChatVisible] = useState(() => loadPanelVisibility('chat'));
    const [statsVisible, setStatsVisible] = useState(() => loadPanelVisibility('stats'));

    // Save visibility states to localStorage when they change
    useEffect(() => {
        savePanelVisibility('leaderboard', leaderboardVisible);
    }, [leaderboardVisible]);

    useEffect(() => {
        savePanelVisibility('chat', chatVisible);
    }, [chatVisible]);

    useEffect(() => {
        savePanelVisibility('stats', statsVisible);
    }, [statsVisible]);

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

            setLeaderboard(data);
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
                setHasPasskey(!!data.has_passkey);
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

    const playerNamesRef = useRef(playerNames);
    useEffect(() => {
        playerNamesRef.current = playerNames;
    }, [playerNames]);

    const playRef = useRef(play);
    useEffect(() => {
        playRef.current = play;
    }, [play]);

    const startAmbienceRef = useRef(startAmbience);
    useEffect(() => {
        startAmbienceRef.current = startAmbience;
    }, [startAmbience]);

    const tRef = useRef(t);
    useEffect(() => {
        tRef.current = t;
    }, [t]);

    useEffect(() => {
        if (!playerId) return;

        const isLocal = window.location.hostname === 'localhost';
        const wsHost = isLocal ? 'localhost:8081' : window.location.host;
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        let socket = null;
        let reconnectTimeout = null;

        const connect = () => {
            if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) return;


            socket = new WebSocket(`${protocol}//${wsHost}/ws?id=${playerId}`);

            socket.onopen = () => {
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
                setWs(null);
                setIsConnecting(true);
                reconnectTimeout = setTimeout(connect, 2000);
            };

            socket.onmessage = (event) => {
                const data = JSON.parse(event.data);
                if (data.type === 'chat') {
                    const text = typeof data.payload === 'string' ? data.payload : data.payload.text;
                    const senderName = typeof data.payload === 'object' ? data.payload.senderName : playerNamesRef.current[data.sender];

                    if (senderName === 'Elsegame') {
                        showToast(text);
                        return;
                    }

                    setMessages(prev => [...prev, {
                        sender: data.sender,
                        senderName: senderName || data.sender,
                        text: text,
                        timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                    }]);
                } else if (data.type === 'identity') {
                    if (data.payload.id === playerIdRef.current) {
                        setNickname(data.payload.name);
                        if (data.payload.language) {
                            i18n.changeLanguage(data.payload.language);
                        }
                        if (data.payload.config) {
                            setTileConfig({
                                tiles: data.payload.config.tiles || {},
                                unicorns: data.payload.config.unicorns || {}
                            });
                            // Populate initial letter values with unicorns
                            setLetterValue(data.payload.config.unicorns || {});
                        }
                    }
                    setPlayerNames(prev => ({
                        ...prev,
                        [data.payload.id]: data.payload.name
                    }));
                } else if (data.type === 'game_start') {
                    const { uuid, rack: newRackLetters, rack_size, letter_values, time_left, tile_counts, unicorns, players: otherPlayers } = data.payload;
                    const size = rack_size || newRackLetters.length;

                    // Grouped Join Toast
                    if (otherPlayers && otherPlayers.length > 0) {
                        const playersList = otherPlayers.join(', ').replace(/, ([^,]*)$/, ` ${tRef.current('app.and', 'and')} $1`);
                        showToast(tRef.current('app.players_starting', { players: playersList }));
                    } else {
                        showToast(tRef.current('app.players_starting_you'));
                    }

                    const newRack = newRackLetters.map((letter, idx) => ({
                        id: `tile-${idx}-${Date.now()}`,
                        letter,
                        position: idx,
                        isUsed: false
                    }));
                    setGameId(uuid);
                    setRack(newRack);
                    setTimeLeft(time_left);
                    setTotalTime(time_left || 30);
                    setLetterValue(letter_values || 0);
                    setTileConfig({ tiles: tile_counts || {}, unicorns: unicorns || {} });
                    setResults(null);
                    setGuess(Array(size).fill(null));
                    setIsLocked(false);
                    setFeedback({ text: '', type: '' });
                    autoSubmittedRef.current = false; // Reset for new game
                    startAmbienceRef.current(); // Start background loop
                    fetchLeaderboard();
                } else if (data.type === 'timer') {
                    if (data.payload && data.payload.time_left !== undefined) {
                        const newTime = Math.max(0, data.payload.time_left);
                        setTimeLeft(newTime);
                    }
                } else if (data.type === 'play') {
                    const playObj = {
                        player: data.sender,
                        playerName: data.payload.playerName || playerNamesRef.current[data.sender] || data.sender,
                        word: data.payload.word,
                        score: data.payload.score,
                        timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                    };

                    // Toast Notification for Mobile/Subtle UI
                    const score = data.payload.score;
                    const isSplat = score >= 40;

                    let toastMsg;
                    if (playObj.word) {
                        toastMsg = `${playObj.playerName} played ${playObj.word} for ${score} pts. ${isSplat ? '💥' : ''}`;
                    } else {
                        toastMsg = `${playObj.playerName} played a word for ${score} pts. ${isSplat ? '💥' : ''}`;
                    }
                    showToast(toastMsg, isSplat);

                    if (isSplat) {
                        playRef.current('bigsplat');
                    }

                    if (data.sender === playerIdRef.current) {
                        setFeedback({ text: tRef.current('app.accepted'), type: 'success' });
                        setIsLocked(true);
                        setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                    }
                } else if (data.type === 'player_joined') {
                    if (data.payload.id !== playerIdRef.current) {
                        showToast(tRef.current('app.player_joined', { name: data.payload.name }));
                    }
                } else if (data.type === 'error') {
                    setFeedback({ text: data.payload, type: 'error' });
                    setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                } else if (data.type === 'play_result') {
                    // No longer tracking historical plays in state
                } else if (data.type === 'game_end') {
                    const resultsData = {
                        results: data.payload.results || [],
                        summary: data.payload.summary || (data.payload.results && data.payload.results.length > 0 ? tRef.current('results.round_over') : tRef.current('results.no_plays_round')),
                        is_solo: data.payload.is_solo || false
                    };
                    if (resultsData.results.length > 0 && data.payload.definition) {
                        resultsData.results[0].definition = data.payload.definition;
                    }
                    setResults(resultsData);
                    setIsLocked(true);
                    playRef.current('game_over');
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

    const showToast = useCallback((message, isSplat = false) => {
        const id = Date.now();
        setToasts(prev => [...prev, { id, message, isSplat }]);
        setTimeout(() => {
            setToasts(prev => prev.filter(t => t.id !== id));
        }, 2000); // 2 seconds as requested
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
        if (timeLeft <= 0 && !isLocked && !autoSubmittedRef.current && guessRef.current.some(g => g !== null)) {
            // Build word from guess slots
            const word = guessRef.current.map(g => g ? g.char : '').join('').toUpperCase().trim();
            if (word.length > 0 && ws && ws.readyState === WebSocket.OPEN) {

                autoSubmittedRef.current = true;
                ws.send(JSON.stringify({ type: 'play', payload: { word } }));
            }
        }
    }, [timeLeft, isLocked, ws]);
    // Wait, if guess changes while timeLeft is 0, we might want to submit? No, usually it's at the transition.

    const handleTileClick = (tile, source) => {
        if (isLocked || timeLeft === 0) return;

        if (source === 'rack') {
            moveTileToGuess(tile);
        } else {
            // Return to rack
            returnToRack(source);
        }
    };

    const playTile = (tileId, letter, slotIndex) => {
        const tile = rack.find(t => t.id === tileId);
        if (!tile) return;

        const newGuess = [...guess];
        // Convert to lowercase to indicate it's a blank (0 points)
        newGuess[slotIndex] = { id: tileId, char: letter.toLowerCase(), originalLetter: '_' };
        setGuess(newGuess);
        // Mark tile as used instead of removing it
        setRack(prev => prev.map(t => t.id === tileId ? { ...t, isUsed: true } : t));
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
        setGuess(Array(8).fill(null));
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
                (targetIndex === -1 ? -1 : currentGuess.length - 1 - targetIndex);

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
        // Ignore if typing in an input, textarea, or content-editable element
        if (
            e.target.tagName === 'INPUT' ||
            e.target.tagName === 'TEXTAREA' ||
            e.target.isContentEditable ||
            e.target.closest('.chat-input-area') // Extra safety for our own chat
        ) return;

        // Only handle keys if results modal isn't open and game is active
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
        const word = guess.map(g => g ? g.char : '').join('').trim();

        if (word.length === 0 || !ws) {
            return;
        }

        const msg = JSON.stringify({ type: 'play', payload: { word } });


        // Tiered celebratory effects
        const len = word.length;
        if (len === 6) {
            play('placement'); // Placeholder for squirt
        } else if (len === 7) {
            play('placement');
            setTimeout(() => play('placement'), 150);
        } else if (len >= 8) {
            play('bigsplat');
        }

        ws.send(msg);
    };

    const sendMessage = (text) => {
        if (ws) {
            const msg = JSON.stringify({
                type: 'chat',
                payload: text
            });

            ws.send(msg);
        } else {
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

    const handleRegisterPasskeyComplete = () => {
        setHasPasskey(true);
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
        <div className={`game-container ${isFocusMode ? 'focus-mode' : ''}`}>
            <Sidebar
                isOpen={sidebarOpen}
                onClose={() => setSidebarOpen(false)}
                isFocusMode={isFocusMode}
                setIsFocusMode={setIsFocusMode}
                leaderboardVisible={leaderboardVisible}
                setLeaderboardVisible={setLeaderboardVisible}
                chatVisible={chatVisible}
                setChatVisible={setChatVisible}
                statsVisible={statsVisible}
                setStatsVisible={setStatsVisible}
                showRules={showRules}
                setShowRules={setShowRules}
                showDonations={showDonations}
                setShowDonations={setShowDonations}
                isMuted={isMuted}
                toggleMute={toggleMute}
                isAmbienceEnabled={isAmbienceEnabled}
                toggleAmbience={toggleAmbience}
                language={i18n.language}
                onLanguageChange={(lang) => {
                    i18n.changeLanguage(lang);
                    if (ws && ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: 'set_language',
                            payload: { language: lang }
                        }));
                    }
                }}
                handleLogout={handleLogout}
                nickname={nickname}
                autoClose={() => setSidebarOpen(false)}
            />

            {!isFocusMode && (
                <header>
                    <div className="header-left">
                        <button className="mobile-menu-btn" onClick={() => setSidebarOpen(true)}>☰</button>
                        <div className="header-content">
                            <h1 style={{ whiteSpace: 'nowrap' }}>wordw<span className="splat">💥</span>nk</h1>
                            {nickname && <div className="user-nickname">{t('app.playing_as')}: <strong>{nickname}</strong></div>}
                        </div>
                    </div>

                    <div className="header-toggles desktop-only">
                        <button
                            className={`panel-toggle ${leaderboardVisible ? 'active' : ''}`}
                            onClick={() => setLeaderboardVisible(!leaderboardVisible)}
                        >
                            Leaderboard
                        </button>
                        <button
                            className={`panel-toggle ${chatVisible ? 'active' : ''}`}
                            onClick={() => setChatVisible(!chatVisible)}
                        >
                            Chat
                        </button>
                    </div>

                    <div className="header-actions desktop-only">
                        {/* Group 1: Authentication */}
                        <div className="button-group">
                            <button className="header-btn wtf-btn" onClick={() => setShowRules(!showRules)} title="Rules">{t('app.help_label')}</button>
                            <button className="header-btn don-btn" onClick={() => setShowDonations(!showDonations)} title="Donate">🤗</button>
                            <button className="header-btn" onClick={() => setStatsVisible(!statsVisible)} title="Stats">🏆</button>
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
                                <option value="fr">FR</option>
                            </select>
                        </div>
                    </div>

                    <div className="header-actions mobile-only">
                        <button className="header-btn don-btn" onClick={() => setShowDonations(!showDonations)} title="Donate">🤗</button>
                    </div>
                </header>
            )}

            {isFocusMode && (
                <button className="focus-exit-btn" onClick={() => setIsFocusMode(false)} title="Exit Focus Mode">
                    ✕
                </button>
            )}

            <main className="game-area">
                <div className="main-game-layout">
                    <div className="center-panel">
                        {isAuthenticated && !hasPasskey && (
                            <PasskeySetup onComplete={handleRegisterPasskeyComplete} />
                        )}
                        <div className="rack-section">
                            <div className="section-label">{t('app.rack_label')}</div>
                            <div className="rack-content">
                                <div className="rack-container clickable">
                                    {Array.from({ length: rack.length }).map((_, position) => {
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
                                <Timer seconds={timeLeft} total={totalTime} />
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
                                    const isBonusSlot = i >= 5; // Slots 6+ (indices 5+)
                                    const bonusPoints = isBonusSlot ? 5 * Math.pow(2, i - 5) : 0;

                                    return (
                                        <div
                                            key={i}
                                            className={`board-slot ${slot ? 'filled' : 'empty'} ${isFirstEmpty && !isLocked && timeLeft > 0 ? 'focused' : ''} ${isBonusSlot ? 'bonus' : ''}`}
                                            onClick={() => slot && returnToRack(i)}
                                        >
                                            {isBonusSlot && slot && (
                                                <div className="slot-badge">+{bonusPoints}</div>
                                            )}
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

            {!isFocusMode && leaderboardVisible && (
                <DraggablePanel
                    title={t('app.leaderboard')}
                    id="leaderboard"
                    initialPos={{ x: 20, y: 150 }}
                    initialSize={{ width: 250, height: 400 }}
                    onClose={() => setLeaderboardVisible(false)}
                    storageKey="leaderboard"
                >
                    <Leaderboard players={leaderboard.leaders || []} />
                </DraggablePanel>
            )}

            {!isFocusMode && statsVisible && (
                <DraggablePanel
                    title="Stats"
                    id="stats"
                    initialPos={{ x: window.innerWidth / 2 - 150, y: 150 }}
                    initialSize={{ width: 300, height: 400 }}
                    onClose={() => setStatsVisible(false)}
                    storageKey="stats"
                >
                    <PlayerStats data={leaderboard} />
                </DraggablePanel>
            )}


            {!isFocusMode && chatVisible && (
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

            {!isFocusMode && showRules && (
                <DraggablePanel
                    id="rules"
                    title="WTF?!"
                    icon="❓"
                    onClose={() => setShowRules(false)}
                    initialPos={{ x: window.innerWidth / 2 - 200, y: 150 }}
                    initialSize={{ width: 400, height: 450 }}
                >
                    <div className="rules-panel">
                        <p className="rules-text">{t('app.rules_summary')}</p>

                        <div className="rules-legend">
                            <div className="legend-item">
                                <span className="legend-icon">🦄</span>
                                <div>
                                    <strong>Unicorns (see below)</strong>: Two tiles worth 10 pts. Very rare, very powerful.
                                </div>
                            </div>
                            <div className="legend-item">
                                <span className="legend-icon">⭐</span>
                                <div>
                                    <strong>Unique Word Bonus</strong>: find a word no one else did for +5 pts.
                                </div>
                            </div>
                            <div className="legend-item">
                                <span className="legend-icon">🚀</span>
                                <div>
                                    <strong>Length Bonus</strong>: starts at 6 letters (+5) and doubles every letter after.
                                </div>
                            </div>
                        </div>

                        <div className="tile-stats-section">
                            <h3>{t('app.tile_frequencies')}</h3>
                            <div className="tile-grid">
                                {Object.entries(tileConfig.tiles)
                                    .sort(([a], [b]) => a.localeCompare(b))
                                    .map(([char, count]) => {
                                        const isUnicorn = tileConfig.unicorns[char];
                                        const score = typeof letterValue === 'object' ? letterValue[char] : 0;
                                        return (
                                            <div key={char} className={`tile-stat-item ${isUnicorn ? 'unicorn-gem' : ''}`}>
                                                <span className="tile-count nw">{count}x</span>
                                                <span className="tile-char">{char}</span>
                                                {score > 0 && (
                                                    <span className="tile-score se">+{score}</span>
                                                )}
                                            </div>
                                        );
                                    })}
                            </div>
                        </div>
                        <div className="rules-footer">
                            v{__APP_VERSION__} · <a href="https://github.com/ronstr8/wordwank" target="_blank" rel="noopener noreferrer" style={{ color: 'inherit' }}>github.com/ronstr8/wordwank</a>
                        </div>
                    </div>
                </DraggablePanel>
            )}

            {!isFocusMode && showDonations && (
                <DraggablePanel
                    id="donations"
                    title={t('app.donate_title')}
                    onClose={() => setShowDonations(false)}
                    initialPos={{ x: window.innerWidth / 2 - 150, y: 200 }}
                    initialSize={{ width: 300, height: 400 }}
                >
                    <div className="donation-panel">
                        <div className="donation-emoji">🤗</div>
                        <p className="donation-text">{t('app.donate_desc')}</p>

                        <div className="donation-options">
                            <a
                                href={`https://www.paypal.com/donate/?business=${encodeURIComponent(CONFIG.PAYPAL_EMAIL)}&no_recurring=0&currency_code=USD`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="donation-link paypal"
                            >
                                <span>PayPal</span>
                                <span className="donation-subtitle">Fast & Secure</span>
                            </a>

                            <div className="donation-divider">{t('app.donate_or')}</div>

                            <div className="donation-link stripe-placeholder">
                                <span>Stripe</span>
                                <span className="donation-subtitle">Coming Soon</span>
                            </div>
                        </div>

                        <p className="donation-footer">{t('app.donate_footer')}</p>
                    </div>
                </DraggablePanel>
            )}

            {results && <Results data={results} onClose={joinGame} playerNames={playerNames} isFocusMode={isFocusMode} />}

            <div className="toast-container">
                {toasts.map(toast => (
                    <div key={toast.id} className={`toast ${toast.isSplat ? 'splat' : ''}`}>
                        {toast.message}
                    </div>
                ))}
            </div>

            {
                (isConnecting || connectionError || (rack.length === 0 && !results)) && (
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
                )
            }
        </div >
    )
}

export default App
