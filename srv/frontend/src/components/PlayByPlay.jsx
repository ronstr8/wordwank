import './Panel.css'

const PlayByPlay = ({ plays }) => {
    const safePlays = Array.isArray(plays) ? plays : [];
    return (
        <div className="panel-content">
            {safePlays.map((play, i) => (
                <div key={i} className={`play-entry ${play.type === 'separator' ? 'separator' : ''}`}>
                    <span className="timestamp">[{play.timestamp}]</span>
                    <span className="play-message">
                        {play.type === 'separator' ? (
                            <span className="new-game-marker">--- New Game Started ---</span>
                        ) : (
                            <>
                                <strong>{play.playerName || play.player}</strong>
                                {play.word ? (
                                    <> played <strong>{play.word}</strong> for <strong>{play.score}</strong> pts.</>
                                ) : (
                                    <> played a word for <strong>{play.score}</strong> pts.</>
                                )}
                            </>
                        )}
                    </span>
                </div>
            ))}
            {safePlays.length === 0 && <div className="empty-msg">Waiting for plays...</div>}
        </div>
    )
}

export default PlayByPlay
