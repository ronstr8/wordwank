import { useState, useEffect, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import Messages from './components/Messages'
import Results from './components/Results'
import DraggablePanel from './components/DraggablePanel'
import useSound from './hooks/useSound'
import usePlayerAuth from './hooks/usePlayerAuth'
import useGameState from './hooks/useGameState'
import useGameSocket from './hooks/useGameSocket'
import useGameController from './hooks/useGameController'
import useInteractionHandler from './hooks/useInteractionHandler'
import PlayerStats from './components/PlayerStats'
import Login from './components/Login'
import Sidebar from './components/Sidebar'
import GameHeader from './components/GameHeader'
import GameArea from './components/GameArea'
import PlayFeed from './feed/PlayFeed'
import usePlayFeed from './feed/usePlayFeed'
import { CONFIG } from './config'
import { lengthBonus } from './scoring'
import './App.css'
import './LoadingModal.css'
import './JumbleButton.css'
import './components/Toast.css'

// Length-bonus numbers for the rules text.
function rulesNumbers(rackSize, lengthBonusStart, lengthBonusBase) {
    return {
        rack_size: rackSize,
        bonus_len: lengthBonusStart,
        bonus_base: lengthBonusBase,
        full_bonus: lengthBonus(rackSize, lengthBonusStart, lengthBonusBase), // using every tile
    };
}

function App() {
    const { t, i18n } = useTranslation()
    const { play, startAmbience, isMuted, toggleMute, isAmbienceEnabled, toggleAmbience } = useSound()

    // 1. Auth Hook
    const auth = usePlayerAuth(i18n)

    // 2. Game State Hook
    const state = useGameState(t)

    // 3. UI State (Visibility, Modes)
    const [isFocusMode, setIsFocusMode] = useState(() => {
        try {
            const saved = localStorage.getItem('focus_mode')
            return saved !== null ? JSON.parse(saved) : false
        } catch { return false }
    })
    const [sidebarOpen, setSidebarOpen] = useState(false)
    const [showRules, setShowRules] = useState(false)
    const [showDonations, setShowDonations] = useState(false)
    const [statsData, setStatsData] = useState(null)
    const [messagesVisible, setMessagesVisible] = useState(() => {
        try {
            const saved = localStorage.getItem('panel_visible_messages')
            return saved !== null ? JSON.parse(saved) : true
        } catch { return true }
    })
    const [statsVisible, setStatsVisible] = useState(() => {
        try {
            const saved = localStorage.getItem('panel_visible_stats')
            return saved !== null ? JSON.parse(saved) : false
        } catch { return false }
    })

    const fetchLeaderboard = useCallback(async () => {
        try {
            const resp = await fetch('/players/leaderboard')
            if (resp.ok) setStatsData(await resp.json())
        } catch (err) { console.error('Failed to fetch stats:', err) }
    }, [])

    // 4. Game Controller (Event Dispatcher)
    const feed = usePlayFeed()
    const controller = useGameController({
        state: { ...state, playerId: auth.playerId, setNickname: auth.setNickname },
        t, i18n, play, startAmbience, fetchLeaderboard,
        pushFeed: feed.push
    })

    // 5. Socket Hook
    const { sendMessage, isConnecting, connectionError } = useGameSocket({
        playerId: auth.playerId,
        nickname: auth.nickname,
        i18n,
        ...controller
    })

    // 6. Interaction Hook
    const interaction = useInteractionHandler({
        state, sendMessage, play, t
    })

    // 7. Effects
    useEffect(() => { localStorage.setItem('focus_mode', JSON.stringify(isFocusMode)) }, [isFocusMode])
    useEffect(() => { localStorage.setItem('panel_visible_messages', JSON.stringify(messagesVisible)) }, [messagesVisible])
    useEffect(() => { localStorage.setItem('panel_visible_stats', JSON.stringify(statsVisible)) }, [statsVisible])

    // Auto-submit effect
    const autoSubmittedRef = useRef(false)
    useEffect(() => {
        if (state.timeLeft <= 0 && !state.isLocked && !autoSubmittedRef.current && state.guessRef.current.some(g => g !== null)) {
            const word = state.guessRef.current.map(g => g ? g.char : '').join('').toUpperCase().trim()
            if (word.length > 0) {
                autoSubmittedRef.current = true
                sendMessage('play', { word })
            }
        }
        if (state.timeLeft > 0) autoSubmittedRef.current = false
    }, [state.timeLeft, state.isLocked, state.guessRef, sendMessage])

    // Timer effect
    useEffect(() => {
        if (state.timeLeft > 0) {
            const timer = setInterval(() => state.handleTimerTick(), 1000)
            return () => clearInterval(timer)
        }
    }, [state.timeLeft, state.handleTimerTick])

    if (auth.isAuthChecking) {
        return (
            <div className="loading-modal">
                <div className="loading-card">
                    <div className="loading-spinner"></div>
                    <h2>{t('app.loading')}</h2>
                    <p>{t('auth.logging_in')}</p>
                </div>
            </div>
        )
    }

    if (!auth.isAuthenticated) {
        return <Login onLoginSuccess={() => auth.checkAuth()} />
    }

    const isLogodal = statsData?.leaders?.[0]?.name === auth.nickname

    const joinGame = () => {
        state.setResults(null)
        sendMessage('join', {})
    }

    const handleInvite = () => {
        if (!state.gameId) return
        const url = `${window.location.protocol}//${window.location.host}?invite=${state.gameId}`
        navigator.clipboard.writeText(url)
        state.showToast(t('app.invite_copied'))
    }

    const handleLanguageChange = (lang) => {
        i18n.changeLanguage(lang)
        sendMessage('set_language', { language: lang })
    }

    return (
        <div className={`game-container ${isFocusMode ? 'focus-mode' : ''}`}>

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
                onLanguageChange={handleLanguageChange}
                handleLogout={auth.handleLogout}
                nickname={auth.nickname}
                autoClose={() => setSidebarOpen(false)}
                gameId={state.gameId}
                showToast={state.showToast}
                handleInvite={handleInvite}
                supportedLangs={state.supportedLangs}
                feedMode={feed.mode}
                setFeedMode={feed.setMode}
            />

            {!isFocusMode && (
                <GameHeader
                    nickname={auth.nickname}
                    isLogodal={isLogodal}
                    onOpenSidebar={() => setSidebarOpen(true)}
                    messagesVisible={messagesVisible}
                    setMessagesVisible={setMessagesVisible}
                    showRules={showRules}
                    setShowRules={setShowRules}
                    handleInvite={handleInvite}
                    gameId={state.gameId}
                    statsVisible={statsVisible}
                    setStatsVisible={setStatsVisible}
                    handleLogout={auth.handleLogout}
                    isMuted={isMuted}
                    toggleMute={toggleMute}
                    isAmbienceEnabled={isAmbienceEnabled}
                    toggleAmbience={toggleAmbience}
                    language={i18n.language}
                    supportedLangs={state.supportedLangs}
                    onLanguageChange={handleLanguageChange}
                    feedMode={feed.mode}
                    cycleFeedMode={feed.cycleMode}
                />
            )}

            <PlayFeed mode={feed.mode} items={feed.items} />

            {isFocusMode && (
                <button className="focus-exit-btn" onClick={() => setIsFocusMode(false)} title={t('app.exit_focus')}>✕</button>
            )}

            <GameArea 
                state={state}
                interaction={interaction}
                isAuthenticated={auth.isAuthenticated}
            />

            {state.blankChoice && (
                <div className="blank-modal-overlay">
                    <div className="blank-modal">
                        <h3>{t('app.select_blank')}</h3>
                        <div className="letter-grid">
                            {"ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map(l => (
                                <button key={l} className="letter-btn" onClick={() => interaction.playTile(state.blankChoice.tileId, l, state.blankChoice.slotIndex)}>{l}</button>
                            ))}
                        </div>
                        <button className="cancel-btn" onClick={() => state.setBlankChoice(null)}>{t('app.cancel')}</button>
                    </div>
                </div>
            )}

            {statsVisible && (
                <DraggablePanel title="Stats" id="stats" initialPos={{ x: window.innerWidth / 2 - 150, y: 150 }} initialSize={{ width: 300, height: 400 }} onClose={() => setStatsVisible(false)} storageKey="stats">
                    <PlayerStats data={statsData} />
                </DraggablePanel>
            )}

            {messagesVisible && (
                <DraggablePanel title={t('app.messages_title', 'Messages')} id="messages" initialPos={{ x: window.innerWidth - 320, y: 380 }} initialSize={{ width: 300, height: 400 }} onClose={() => setMessagesVisible(false)} storageKey="messages">
                    <Messages messages={state.messages} onSendMessage={(text) => sendMessage('chat', text)} />
                </DraggablePanel>
            )}

            {showRules && (
                <DraggablePanel id="rules" title="WTF?!" icon="❓" onClose={() => setShowRules(false)} initialPos={{ x: window.innerWidth / 2 - 200, y: 150 }} initialSize={{ width: 400, height: 450 }}>
                    <div className="rules-panel">
                        <p className="rules-text">{t('app.rules_summary', rulesNumbers(state.rackSize, state.lengthBonusStart, state.lengthBonusBase))}</p>
                        <div className="rules-legend">
                            <div className="legend-item"><span className="legend-icon">🦄</span><div><strong>Unicorns</strong>: Two tiles worth 10 pts. Very rare.</div></div>
                            <div className="legend-item"><span className="legend-icon">🚀</span><div><strong>Length Bonus</strong>: starts at {state.lengthBonusStart} letters (+{state.lengthBonusBase}) and doubles every letter after.</div></div>
                        </div>
                        <div className="tile-stats-section">
                            <h3>{t('app.tile_frequencies')}</h3>
                            <div className="tile-grid">
                                {Object.entries(state.tileConfig.tiles).sort(([a], [b]) => a.localeCompare(b)).map(([char, count]) => (
                                    <div key={char} className={`tile-stat-item ${state.tileConfig.unicorns[char] ? 'unicorn-gem' : ''}`}>
                                        <span className="tile-count nw">{count}x</span>
                                        <span className="tile-char">{char}</span>
                                        {state.baseLetterValue[char] > 0 && <span className="tile-score se">+{state.baseLetterValue[char]}</span>}
                                    </div>
                                ))}
                            </div>
                        </div>
                        <div className="rules-footer">
                            v{__APP_VERSION__} · {__GIT_SHA__} · {__BUILD_DATE__} ·<a href={CONFIG.PROJECT_CODE_LINK} target="_blank" rel="noopener noreferrer">GitHub</a>
                        </div>
                    </div>
                </DraggablePanel>
            )}

            {showDonations && (
                <DraggablePanel id="donations" title={t('app.donate_title')} onClose={() => setShowDonations(false)} initialPos={{ x: window.innerWidth / 2 - 150, y: 200 }} initialSize={{ width: 300, height: 400 }}>
                    <div className="donation-panel">
                        <div className="donation-emoji">🤗</div>
                        <p className="donation-text">{t('app.donate_desc')}</p>
                        <div className="donation-options">
                            {CONFIG.PAYPAL_ENABLED && <a href={`https://www.paypal.com/donate/?business=${encodeURIComponent(CONFIG.PAYPAL_EMAIL)}&no_recurring=0&currency_code=USD`} target="_blank" rel="noopener noreferrer" className="donation-link paypal"><span>PayPal</span></a>}
                            {CONFIG.KOFI_ENABLED && <a href={`https://ko-fi.com/${CONFIG.KOFI_ID || 'logodal'}`} target="_blank" rel="noopener noreferrer" className="donation-link kofi"><span>Ko-fi</span></a>}
                        </div>
                    </div>
                </DraggablePanel>
            )}

            {state.results && <Results {...state.results} onClose={joinGame} playerNames={state.playerNames} playerBrands={state.playerBrands} isFocusMode={isFocusMode} />}

            <div className="toast-container">
                {state.toasts.map(toast => <div key={toast.id} className={`toast ${toast.isSplat ? 'splat' : ''}`}>{toast.message}</div>)}
            </div>

            {(isConnecting || connectionError || (state.rack.length === 0 && !state.results)) && (
                <div className="loading-modal">
                    <div className="loading-card">
                        {connectionError ? (
                            <>
                                <div className="error-icon">⚠️</div>
                                <h2>{t('app.connection_error')}</h2>
                                <p>{connectionError}</p>
                                <button className="reload-btn" onClick={() => window.location.reload()}>{t('app.reload')}</button>
                            </>
                        ) : (
                            <>
                                <div className="loading-spinner"></div>
                                <h2>{t('app.loading')}</h2>
                                <p>{state.rack.length === 0 && !isConnecting ? t('app.waiting_next_game') : t('app.connecting')}</p>
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    )
}

export default App
