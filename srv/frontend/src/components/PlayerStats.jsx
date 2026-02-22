import { useTranslation } from 'react-i18next'
import './PlayerStats.css'

const PlayerStats = ({ data }) => {
    const { t } = useTranslation();
    if (!data) return <div className="loading-stats">{t('stats.loading')}</div>;

    const { leaders = [], personal } = data;

    return (
        <div className="stats-container">
            {personal && (
                <div className="personal-stats-section">
                    <h3>{t('stats.your_performance')}</h3>
                    <div className="personal-stats-grid">
                        <div className="stat-card">
                            <span className="stat-value">{personal.score}</span>
                            <span className="stat-label">{t('stats.total_points')}</span>
                        </div>
                        <div className="stat-card">
                            <span className="stat-value">{personal.plays}</span>
                            <span className="stat-label">{t('stats.words_played')}</span>
                        </div>
                    </div>
                </div>
            )}

            <div className="leaderboard-section">
                <h3>{t('stats.global_top_10')}</h3>
                <div className="leaderboard-list">
                    {leaders.map((p, i) => (
                        <div key={i} className="leader-entry">
                            <span className="leader-rank">#{i + 1}</span>
                            <span className="leader-name">{p.name}</span>
                            <span className="leader-score">{p.score}</span>
                        </div>
                    ))}
                    {leaders.length === 0 && <div className="empty-msg">{t('app.no_legends')}</div>}
                </div>
            </div>
        </div>
    )
}

export default PlayerStats
