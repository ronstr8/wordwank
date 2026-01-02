import './Panel.css'

const Leaderboard = ({ players }) => {
    const sortedPlayers = [...players].sort((a, b) => b.totalScore - a.totalScore);

    return (
        <div className="leaderboard-content">
            {sortedPlayers.map((p, i) => (
                <div key={p.playerId} className="leader-row">
                    <span className="leader-rank">#{i + 1}</span>
                    <span className="leader-name">{p.username}</span>
                    <span className="leader-score">{p.totalScore}</span>
                </div>
            ))}
            {sortedPlayers.length === 0 && <div className="empty-msg">No legends yet...</div>}
        </div>
    )
}

export default Leaderboard
