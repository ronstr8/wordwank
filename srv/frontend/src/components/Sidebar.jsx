import { useTranslation } from 'react-i18next';
import './Sidebar.css';

const Sidebar = ({
    isOpen,
    onClose,
    isFocusMode,
    setIsFocusMode,
    leaderboardVisible,
    setLeaderboardVisible,
    playByPlayVisible,
    setPlayByPlayVisible,
    chatVisible,
    setChatVisible,
    statsVisible,
    setStatsVisible,
    showRules,
    setShowRules,
    showDonations,
    setShowDonations,
    isMuted,
    toggleMute,
    isAmbienceEnabled,
    toggleAmbience,
    language,
    onLanguageChange,
    handleLogout,
    nickname,
    autoClose
}) => {
    const { t } = useTranslation();

    const handleAction = (action) => {
        action();
        if (autoClose) autoClose();
    };

    return (
        <>
            <div className={`sidebar-overlay ${isOpen ? 'open' : ''}`} onClick={onClose} />
            <div className={`sidebar ${isOpen ? 'open' : ''}`}>
                <div className="sidebar-header">
                    <h2>Menu</h2>
                    <button className="sidebar-close" onClick={onClose}>×</button>
                </div>

                <div className="sidebar-content">
                    {nickname && (
                        <div className="sidebar-user">
                            <span>{t('app.playing_as')}:</span>
                            <strong>{nickname}</strong>
                        </div>
                    )}

                    <div className="sidebar-section">
                        <h3>Game Modes</h3>
                        <button
                            className={`sidebar-btn ${isFocusMode ? 'active' : ''}`}
                            onClick={() => handleAction(() => setIsFocusMode(!isFocusMode))}
                        >
                            <span className="sidebar-icon">🎯</span>
                            Focus Mode {isFocusMode ? 'ON' : 'OFF'}
                        </button>
                    </div>

                    <div className="sidebar-section">
                        <h3>Panels</h3>
                        <button
                            className={`sidebar-btn ${leaderboardVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setLeaderboardVisible(!leaderboardVisible))}
                        >
                            <span className="sidebar-icon">🏆</span>
                            Leaderboard
                        </button>
                        <button
                            className={`sidebar-btn ${playByPlayVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setPlayByPlayVisible(!playByPlayVisible))}
                        >
                            <span className="sidebar-icon">🎬</span>
                            Play-by-Play
                        </button>
                        <button
                            className={`sidebar-btn ${chatVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setChatVisible(!chatVisible))}
                        >
                            <span className="sidebar-icon">💬</span>
                            Chat
                        </button>
                        <button
                            className={`sidebar-btn ${statsVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setStatsVisible(!statsVisible))}
                        >
                            <span className="sidebar-icon">📊</span>
                            Stats
                        </button>
                    </div>

                    <div className="sidebar-section">
                        <h3>Audio</h3>
                        <button className="sidebar-btn" onClick={toggleAmbience}>
                            <span className="sidebar-icon">{isAmbienceEnabled ? '🎵' : '🔇'}</span>
                            Ambience: {isAmbienceEnabled ? 'ON' : 'OFF'}
                        </button>
                        <button className="sidebar-btn" onClick={toggleMute}>
                            <span className="sidebar-icon">{isMuted ? '🔇' : '🔊'}</span>
                            Master Sound: {isMuted ? 'OFF' : 'ON'}
                        </button>
                    </div>

                    <div className="sidebar-section">
                        <h3>Language</h3>
                        <div className="sidebar-lang-picker">
                            <button className={language === 'en' ? 'active' : ''} onClick={() => onLanguageChange('en')}>EN</button>
                            <button className={language === 'es' ? 'active' : ''} onClick={() => onLanguageChange('es')}>ES</button>
                            <button className={language === 'fr' ? 'active' : ''} onClick={() => onLanguageChange('fr')}>FR</button>
                        </div>
                    </div>

                    <div className="sidebar-footer">
                        <button className="sidebar-btn" onClick={() => handleAction(() => setShowRules(true))}>
                            <span className="sidebar-icon">❓</span>
                            Rules
                        </button>
                        <button className="sidebar-btn" onClick={() => handleAction(() => setShowDonations(true))}>
                            <span className="sidebar-icon">🤗</span>
                            Donate
                        </button>
                        <button className="sidebar-btn logout" onClick={handleLogout}>
                            <span className="sidebar-icon">🚪</span>
                            Logout
                        </button>
                    </div>
                </div>
            </div>
        </>
    );
};

export default Sidebar;
