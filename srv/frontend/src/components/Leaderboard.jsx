import './Panel.css'

const Leaderboard = ({ players }) => {
    const sortedPlayers = Array.isArray(players) ? [...players].sort((a, b) => b.score - a.score) : [];

    return (
        <div className="leaderboard-content">
            {sortedPlayers.map((p, i) => (
                <div key={i} className="leader-row">
                    <span className="leader-rank">#{i + 1}</span>
                    <span className="leader-name">{p.name}</span>
                    <span className="leader-score">{p.score}</span>
                </div>
            ))}
            {sortedPlayers.length === 0 && <div className="empty-msg">No legends yet...</div>}
        </div>
    )
}

export default Leaderboard
