import { useTranslation } from 'react-i18next';
import './Sidebar.css';

const Sidebar = ({
    isOpen,
    onClose,
    isFocusMode,
    setIsFocusMode,
    leaderboardVisible,
    setLeaderboardVisible,
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
    autoClose,
    gameId,
    showToast,
    handleInvite
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
                    <h2>{t('app.menu_title')}</h2>
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
                        <h3>{t('app.game_modes_title')}</h3>
                        <button
                            className={`sidebar-btn ${isFocusMode ? 'active' : ''}`}
                            onClick={() => handleAction(() => setIsFocusMode(!isFocusMode))}
                        >
                            <span className="sidebar-icon">🎯</span>
                            {t('app.focus_mode')} {isFocusMode ? t('app.on') : t('app.off')}
                        </button>
                    </div>


                    <div className="sidebar-section">
                        <h3>{t('app.panels_title')}</h3>
                        <button
                            className={`sidebar-btn ${leaderboardVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setLeaderboardVisible(!leaderboardVisible))}
                        >
                            <span className="sidebar-icon">🏆</span>
                            {t('app.leaderboard')}
                        </button>
                        <button
                            className={`sidebar-btn ${chatVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setChatVisible(!chatVisible))}
                        >
                            <span className="sidebar-icon">💬</span>
                            {t('app.chat')}
                        </button>
                        <button
                            className={`sidebar-btn ${statsVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setStatsVisible(!statsVisible))}
                        >
                            <span className="sidebar-icon">📊</span>
                            {t('app.stats_button')}
                        </button>
                    </div>

                    <div className="sidebar-section">
                        <h3>{t('app.audio_title')}</h3>
                        <button className="sidebar-btn" onClick={toggleAmbience}>
                            <span className="sidebar-icon">{isAmbienceEnabled ? '🎵' : '🔇'}</span>
                            {t('app.ambience_label')}: {isAmbienceEnabled ? t('app.on') : t('app.off')}
                        </button>
                        <button className="sidebar-btn" onClick={toggleMute}>
                            <span className="sidebar-icon">{isMuted ? '🔇' : '🔊'}</span>
                            {t('app.master_sound_label')}: {isMuted ? t('app.off') : t('app.on')}
                        </button>
                    </div>

                    <div className="sidebar-section">
                        <h3>{t('app.language_title')}</h3>
                        <div className="sidebar-lang-picker">
                            <button className={language === 'en' ? 'active' : ''} onClick={() => onLanguageChange('en')}>EN</button>
                            <button className={language === 'es' ? 'active' : ''} onClick={() => onLanguageChange('es')}>ES</button>
                            <button className={language === 'fr' ? 'active' : ''} onClick={() => onLanguageChange('fr')}>FR</button>
                            <button className={language === 'de' ? 'active' : ''} onClick={() => onLanguageChange('de')}>DE</button>
                        </div>
                    </div>

                    <div className="sidebar-footer">
                        <button className="sidebar-btn" onClick={() => handleAction(() => setShowRules(true))}>
                            <span className="sidebar-icon">❓</span>
                            {t('app.help_label')}
                        </button>
                        <button
                            className="sidebar-btn"
                            onClick={() => handleAction(handleInvite ? handleInvite : () => {
                                if (!gameId) return;
                                const url = `${window.location.protocol}//${window.location.host}?invite=${gameId}`;
                                navigator.clipboard.writeText(url);
                                showToast(t('app.invite_copied'));
                            })}
                            disabled={!gameId}
                        >
                            <span className="sidebar-icon">🔗</span>
                            {t('app.invite_friend')}
                        </button>
                        <button className="sidebar-btn" onClick={() => handleAction(() => setShowDonations(true))}>
                            <span className="sidebar-icon">🤗</span>
                            {t('app.donate_button')}
                        </button>
                        <button className="sidebar-btn logout" onClick={handleLogout}>
                            <span className="sidebar-icon">🚪</span>
                            {t('auth.logout')}
                        </button>
                        <div className="sidebar-version">
                            v{__APP_VERSION__} · {__BUILD_DATE__}
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
};

export default Sidebar;
