import { useTranslation } from 'react-i18next';
import { CONFIG } from '../config';
import './Sidebar.css';

const Sidebar = ({
    isOpen,
    onClose,
    isFocusMode,
    setIsFocusMode,
    messagesVisible,
    setMessagesVisible,
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
    handleInvite,
    supportedLangs
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
                            className={`sidebar-btn ${messagesVisible ? 'active' : ''}`}
                            onClick={() => handleAction(() => setMessagesVisible(!messagesVisible))}
                        >
                            <span className="sidebar-icon">💬</span>
                            {t('app.messages_title', 'Messages')}
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
                            {Object.entries(supportedLangs || {}).map(([code, info]) => {
                                const name = typeof info === 'object' ? info.name : info;
                                const count = typeof info === 'object' ? info.word_count : 0;
                                const displayCount = count >= 1000 ? `${Math.round(count / 1000)}k` : count;

                                return (
                                    <button
                                        key={code}
                                        className={language === code ? 'active' : ''}
                                        onClick={() => handleAction(() => onLanguageChange(code))}
                                        title={name}
                                    >
                                        {code.toUpperCase()}
                                        {count > 0 && <span className="lang-count">{displayCount}</span>}
                                    </button>
                                );
                            })}
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
                            v{__APP_VERSION__} · {__BUILD_DATE__} · <a href={CONFIG.PROJECT_CODE_LINK} target="_blank" rel="noopener noreferrer">{CONFIG.PROJECT_CODE_LINK}</a>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
};

export default Sidebar;
