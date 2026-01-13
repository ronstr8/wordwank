import './Panel.css'

const PlayByPlay = ({ plays }) => {
    const safePlays = Array.isArray(plays) ? plays : [];
    return (
        <div className="panel-content">
            {safePlays.map((play, i) => (
                <div key={i} className="play-entry">
                    <span className="timestamp">[{play.timestamp}]</span>
                    <span className="play-message">
                        <strong>{play.playerName || play.player}</strong> played <strong>{play.word}</strong> for <strong>{play.score}</strong> pts.
                    </span>
                </div>
            ))}
            {safePlays.length === 0 && <div className="empty-msg">Waiting for plays...</div>}
        </div>
    )
}

export default PlayByPlay
