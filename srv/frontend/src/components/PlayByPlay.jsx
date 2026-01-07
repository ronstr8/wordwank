import './Panel.css'

const PlayByPlay = ({ plays }) => {
    const safePlays = Array.isArray(plays) ? plays : [];
    return (
        <div className="panel-content">
            {safePlays.map((play, i) => (
                <div key={i} className="play-entry">
                    <span className="timestamp">[{play.timestamp}]</span>
                    <span className="play-message">
                        <strong>{play.player}</strong> played a word worth <strong>{play.score}</strong> points.
                    </span>
                </div>
            ))}
            {safePlays.length === 0 && <div className="empty-msg">Waiting for plays...</div>}
        </div>
    )
}

export default PlayByPlay
