import { useState, useEffect, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import Tile from './components/Tile'
import Timer from './components/Timer'
import Messages from './components/Messages'
import Results from './components/Results'
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
    const [statsData, setStatsData] = useState(null)
    const [feedback, setFeedback] = useState({ text: '', type: '' })
    const [isLocked, setIsLocked] = useState(false)
    const [isConnecting, setIsConnecting] = useState(true)
    const [connectionError, setConnectionError] = useState(null)
    const [blankChoice, setBlankChoice] = useState(null) // { slotIndex, tileId }
    const [letterValue, setLetterValue] = useState({}) // Object mapping char -> points
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
    const [chatToasts, setChatToasts] = useState([]);
    const hasLogConnected = useRef(false);

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

    const [messagesVisible, setMessagesVisible] = useState(() => loadPanelVisibility('messages', true));
    const [statsVisible, setStatsVisible] = useState(() => loadPanelVisibility('stats'));
    const [supportedLangs, setSupportedLangs] = useState({ en: { name: 'English', word_count: 0 } });


    useEffect(() => {
        savePanelVisibility('messages', messagesVisible);
    }, [messagesVisible]);

    useEffect(() => {
        savePanelVisibility('stats', statsVisible);
    }, [statsVisible]);

    useEffect(() => {
        rackRef.current = rack;
    }, [rack]);

    useEffect(() => {
        guessRef.current = guess;
    }, [guess]);

    const logSystemMessage = useCallback((text, type = 'system', data = null) => {
        setMessages(prev => [...prev, {
            sender: 'SYSTEM',
            text,
            isSystem: true,
            type,
            data,
            timestamp: new Date().toLocaleTimeString()
        }]);
    }, []);

    const fetchLeaderboard = useCallback(async () => {
        try {
            const apiPath = '/players/leaderboard';
            const resp = await fetch(apiPath);
            if (!resp.ok) throw new Error(`HTTP error! status: ${resp.status}`);
            const data = await resp.json();
            setStatsData(data);
        } catch (err) {
            console.error('Failed to fetch stats:', err);
            setStatsData(null);
        }
    }, []);

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
            if (!hasLogConnected.current) {
                logSystemMessage(t('app.connecting'));
                hasLogConnected.current = true;
            }
            await checkAuth();
            fetchLeaderboard();
        };
        init();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []); // Only run on mount

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

        const wsHost = window.location.host;
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

                // Auto-join the active game or specific invite
                const urlParams = new URLSearchParams(window.location.search);
                const inviteGid = urlParams.get('invite');
                socket.send(JSON.stringify({
                    type: 'join',
                    payload: inviteGid ? { gid: inviteGid } : {}
                }));

                // Clear the invite param from URL after joining to prevent accidental re-joins on refresh
                if (inviteGid) {
                    const newUrl = window.location.pathname;
                    window.history.replaceState({}, document.title, newUrl);
                }
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
                try {
                    const data = JSON.parse(event.data);
                    console.log('[WS] Received:', data.type, data);

                    if (data.type === 'chat') {
                        const text = typeof data.payload === 'string' ? data.payload : data.payload.text;
                        const senderName = typeof data.payload === 'object' ? data.payload.senderName : playerNamesRef.current[data.sender];

                        const isSystem = !!(data.payload && (data.payload.isSystem || data.sender === 'SYSTEM'));
                        let translatedText = text;
                        if (typeof text === 'string' && text.includes('ai.')) {
                            translatedText = tRef.current(text, { player: senderName || data.sender });
                        }

                        if (senderName === 'Elsegame') {
                            logSystemMessage(translatedText);
                            return;
                        }

                        // Show chat toast notification (left side)
                        if (data.payload && !data.payload.isSeparator && !data.payload.skipToast) {
                            showChatToast(senderName, translatedText);
                        }

                        const msgObj = {
                            sender: data.sender,
                            senderName: senderName || data.sender,
                            text: translatedText,
                            isSystem: isSystem,
                            isSeparator: !!(data.payload && data.payload.isSeparator),
                            timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                        };

                        setMessages(prev => [...prev, msgObj]);
                    }
                    else if (data.type === 'chat_history') {
                        const history = data.payload.map(msg => {
                            const payload = msg.payload || {};
                            const isObject = typeof payload === 'object';
                            return {
                                sender: msg.sender,
                                senderName: (isObject ? payload.senderName : null) || msg.sender,
                                text: isObject ? payload.text : (typeof payload === 'string' ? payload : ''),
                                isSystem: !!(isObject && (payload.isSystem || msg.sender === 'SYSTEM')),
                                isSeparator: !!(isObject && payload.isSeparator),
                                type: isObject ? (payload.type || (msg.type === 'chat' ? payload.type : undefined)) : undefined,
                                data: isObject ? payload.data : undefined,
                                timestamp: new Date(msg.timestamp * 1000).toLocaleTimeString()
                            };
                        });
                        // Use functional update to avoid racing against fresh local messages
                        setMessages(prev => {
                            // Only set history if we don't have a more recent local history 
                            // or merge if necessary. For simplicity, we prioritize history 
                            // but only if it's significantly longer or we are initializing.
                            if (prev.length > history.length) {
                                console.log('[WS] Skipping chat_history: local history is longer/newer');
                                return prev;
                            }
                            return history;
                        });
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
                                setLetterValue(data.payload.config.tile_values || {});
                                if (data.payload.config.languages) {
                                    setSupportedLangs(data.payload.config.languages);
                                }
                            }
                        }
                        setPlayerNames(prev => ({
                            ...prev,
                            [data.payload.id]: data.payload.name
                        }));
                    } else if (data.type === 'game_start') {
                        const { uuid, rack: newRackLetters, rack_size, tile_values, time_left, tile_counts, unicorns, players: otherPlayers } = data.payload;

                        // Removed redundant manual logSystemMessage for game_start
                        // as backend sends a 'chat' message for this.

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
                        setLetterValue(tile_values || {});
                        setTileConfig({ tiles: tile_counts || {}, unicorns: unicorns || {} });
                        setResults(null);
                        setGuess(Array(rack_size || newRackLetters.length).fill(null));
                        setIsLocked(false);
                        setFeedback({ text: '', type: '' });
                        autoSubmittedRef.current = false;
                        startAmbienceRef.current();
                        fetchLeaderboard();
                    } else if (data.type === 'timer') {
                        if (data.payload && data.payload.time_left !== undefined) {
                            const newTime = Math.max(0, data.payload.time_left);
                            setTimeLeft(newTime);
                        }
                    } else if (data.type === 'play') {
                        if (data.sender === playerIdRef.current) {
                            setFeedback({ text: tRef.current('app.accepted'), type: 'success' });
                            setIsLocked(true);
                            setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                        }

                        const score = data.payload.score;
                        const isSplat = score >= 40;
                        if (isSplat) {
                            playRef.current('bigsplat');
                        }

                        // Removed redundant manual log message for 'play'
                        // as backend sends a 'chat' message for this.
                    } else if (data.type === 'player_joined') {
                        if (data.payload.id !== playerIdRef.current) {
                            if (!joinToastShown.current.has(data.payload.id)) {
                                logSystemMessage(tRef.current('app.player_joined', { name: data.payload.name }));
                                joinToastShown.current.add(data.payload.id);
                            }
                        }
                    } else if (data.type === 'player_quit') {
                        if (data.payload.id !== playerIdRef.current) {
                            logSystemMessage(tRef.current('app.player_quit', { name: data.payload.name }));
                        }
                    } else if (data.type === 'error') {
                        setFeedback({ text: data.payload, type: 'error' });
                        setTimeout(() => setFeedback({ text: '', type: '' }), 5000);
                    } else if (data.type === 'game_end') {
                        console.log('[WS] Processing game_end', data.payload);
                        const resultsData = {
                            results: data.payload.results || [],
                            summary: data.payload.summary || (data.payload.results && data.payload.results.length > 0 ? tRef.current('results.round_over') : tRef.current('results.no_plays_round')),
                            is_solo: data.payload.is_solo || false,
                            definition: data.payload.definition,
                            suggested_word: data.payload.suggested_word
                        };

                        if (resultsData.results.length > 0 && data.payload.definition) {
                            resultsData.results[0].definition = data.payload.definition;
                        }
                        setResults(resultsData);
                        setIsLocked(true);

                        // Round over notification
                        // Redundant logSystemMessage removed

                        try {
                            if (playRef.current) playRef.current('game_over');
                        } catch (e) {
                            console.error('[WS] Failed to play game_over sound:', e);
                        }

                        fetchLeaderboard();

                        const resultsTable = (resultsData.results || []).map(r => {
                            const pName = String(r.nickname || r.player || 'Anonymous').padEnd(12);
                            const pScore = String(r.score || 0).padStart(3);
                            const pWord = r.word || '???';
                            return `${pName} : ${pScore} pts (${pWord})`;
                        }).join('\n');

                        setMessages(prev => {
                            const newMsg = {
                                sender: 'SYSTEM',
                                text: resultsData.summary,
                                isSystem: true,
                                type: 'results_table',
                                data: resultsData.results,
                                timestamp: new Date(data.timestamp * 1000).toLocaleTimeString()
                            };

                            // Final safety check against exact message duplication
                            const last = prev[prev.length - 1];
                            if (last && last.text === newMsg.text && last.type === 'results_table') return prev;

                            return [
                                ...prev,
                                newMsg,
                                { isSeparator: true }
                            ];
                        });
                    }
                } catch (err) {
                    console.error('[WS] Error processing message:', err, event.data);
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
    // Ref to track shown join toasts per player per game
    const joinToastShown = useRef(new Set());

    const showChatToast = useCallback((senderName, text) => {
        const id = Date.now();
        setChatToasts(prev => [...prev, { id, senderName, text }]);
        setTimeout(() => {
            setChatToasts(prev => prev.filter(t => t.id !== id));
        }, 3000); // 3 seconds for chat messages
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
        returnToRack(slotIndex);
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

    const handleInvite = () => {
        if (!gameId) return;
        const url = `${window.location.protocol}//${window.location.host}?invite=${gameId}`;
        navigator.clipboard.writeText(url);
        showToast(t('app.invite_copied'));
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
            <div className="version-stamp">v{__APP_VERSION__} · {__BUILD_DATE__}</div>
            <Sidebar
                isOpen={sidebarOpen}
                onClose={() => setSidebarOpen(false)}
                isFocusMode={isFocusMode}
                setIsFocusMode={setIsFocusMode}
                messagesVisible={messagesVisible}
                setMessagesVisible={setMessagesVisible}
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
                gameId={gameId}
                showToast={showToast}
                handleInvite={handleInvite}
                supportedLangs={supportedLangs}
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
                            className={`panel-toggle ${messagesVisible ? 'active' : ''}`}
                            onClick={() => setMessagesVisible(!messagesVisible)}
                        >
                            {t('app.messages_title', 'Messages')}
                        </button>
                    </div>

                    <div className="header-actions desktop-only">
                        {/* Group 1: Authentication */}
                        <div className="button-group">
                            <button className="header-btn wtf-btn" onClick={() => setShowRules(!showRules)} title={t('app.rules_title')}>{t('app.help_label')}</button>
                            <button className="header-btn" onClick={handleInvite} title={t('app.invite_friend')} disabled={!gameId}>🔗</button>
                            <button className="header-btn don-btn" onClick={() => setShowDonations(!showDonations)} title={t('app.donate_button')}>🤗</button>
                            <button className="header-btn" onClick={() => setStatsVisible(!statsVisible)} title={t('app.stats_button')}>🏆</button>
                            <button className="header-btn logout" onClick={handleLogout} title={t('auth.logout')}>
                                🚪
                            </button>
                        </div>

                        {/* Group 2: Audio Controls */}
                        <div className="button-group">
                            <button className="header-btn" onClick={toggleAmbience} title={isAmbienceEnabled ? t('app.music_off') : t('app.music_on')}>
                                {isAmbienceEnabled ? '🎵' : '🔇'}
                            </button>
                            <button className="header-btn" onClick={toggleMute} title={isMuted ? t('app.mute_off') : t('app.mute_on')}>
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
                                {Object.entries(supportedLangs).map(([code, info]) => {
                                    const name = typeof info === 'object' ? info.name : info;
                                    const count = typeof info === 'object' ? info.word_count : 0;
                                    const displayCount = count >= 1000 ? `${Math.round(count / 1000)}k` : count;
                                    return (
                                        <option key={code} value={code}>
                                            {name || code.toUpperCase()} {count > 0 ? `(${displayCount})` : ''}
                                        </option>
                                    );
                                })}
                            </select>
                        </div>
                    </div>

                    <div className="header-actions mobile-only">
                        <button className="header-btn" onClick={handleInvite} title={t('app.invite_friend')} disabled={!gameId}>🔗</button>
                        <button className="header-btn don-btn" onClick={() => setShowDonations(!showDonations)} title={t('app.donate_button')}>🤗</button>
                    </div>
                </header>
            )}

            {isFocusMode && (
                <button className="focus-exit-btn" onClick={() => setIsFocusMode(false)} title={t('app.exit_focus')}>
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

            {!isFocusMode && statsVisible && (
                <DraggablePanel
                    title="Stats"
                    id="stats"
                    initialPos={{ x: window.innerWidth / 2 - 150, y: 150 }}
                    initialSize={{ width: 300, height: 400 }}
                    onClose={() => setStatsVisible(false)}
                    storageKey="stats"
                >
                    <PlayerStats data={statsData} />
                </DraggablePanel>
            )}


            {!isFocusMode && messagesVisible && (
                <DraggablePanel
                    title={t('app.messages_title', 'Messages')}
                    id="messages"
                    initialPos={{ x: window.innerWidth - 320, y: 380 }}
                    initialSize={{ width: 300, height: 400 }}
                    onClose={() => setMessagesVisible(false)}
                    storageKey="messages"
                >
                    <Messages messages={messages} onSendMessage={sendMessage} />
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
                            v{__APP_VERSION__} · {__BUILD_DATE__} · <a href="https://github.com/ronstr8/wordwank" target="_blank" rel="noopener noreferrer" style={{ color: 'inherit' }}>github.com/ronstr8/wordwank</a>
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
                            {CONFIG.PAYPAL_ENABLED && (
                                <a
                                    href={`https://www.paypal.com/donate/?business=${encodeURIComponent(CONFIG.PAYPAL_EMAIL)}&no_recurring=0&currency_code=USD`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="donation-link paypal"
                                >
                                    <span>PayPal</span>
                                    <span className="donation-subtitle">Fast & Secure</span>
                                </a>
                            )}

                            {CONFIG.PAYPAL_ENABLED && CONFIG.KOFI_ENABLED && (
                                <div className="donation-divider">{t('app.donate_or')}</div>
                            )}

                            {CONFIG.KOFI_ENABLED && (
                                <a
                                    href={`https://ko-fi.com/${CONFIG.KOFI_ID || 'wordwank'}`}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="donation-link kofi"
                                >
                                    <span>Ko-fi</span>
                                    <span className="donation-subtitle">{t('app.donate_google_pay', 'Supports Google Pay')}</span>
                                </a>
                            )}
                        </div>

                        <p className="donation-footer">{t('app.donate_footer')}</p>
                    </div>
                </DraggablePanel>
            )}

            {results && <Results {...results} onClose={joinGame} playerNames={playerNames} isFocusMode={isFocusMode} />}

            {/* Play Toasts (Right Side) */}
            <div className="toast-container">
                {toasts.map(toast => (
                    <div key={toast.id} className={`toast ${toast.isSplat ? 'splat' : ''}`}>
                        {toast.message}
                    </div>
                ))}
            </div>

            {/* Chat Toasts (Left Side) */}
            <div className="chat-toast-container">
                {chatToasts.map(toast => (
                    <div key={toast.id} className="chat-toast">
                        <div className="chat-toast-sender">{toast.senderName}</div>
                        <div className="chat-toast-text">{toast.text}</div>
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
