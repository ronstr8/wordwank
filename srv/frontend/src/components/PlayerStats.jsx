import './PlayerStats.css'

const PlayerStats = ({ data }) => {
    if (!data) return <div className="loading-stats">Loading stats...</div>;

    const { leaders = [], personal } = data;

    return (
        <div className="stats-container">
            {personal && (
                <div className="personal-stats-section">
                    <h3>Your Performance</h3>
                    <div className="personal-stats-grid">
                        <div className="stat-card">
                            <span className="stat-value">{personal.score}</span>
                            <span className="stat-label">Total Points</span>
                        </div>
                        <div className="stat-card">
                            <span className="stat-value">{personal.plays}</span>
                            <span className="stat-label">Words Played</span>
                        </div>
                    </div>
                </div>
            )}

            <div className="leaderboard-section">
                <h3>Global Top 10</h3>
                <div className="leaderboard-list">
                    {leaders.map((p, i) => (
                        <div key={i} className="leader-entry">
                            <span className="leader-rank">#{i + 1}</span>
                            <span className="leader-name">{p.name}</span>
                            <span className="leader-score">{p.score}</span>
                        </div>
                    ))}
                    {leaders.length === 0 && <div className="empty-msg">No legends yet...</div>}
                </div>
            </div>
        </div>
    )
}

export default PlayerStats
