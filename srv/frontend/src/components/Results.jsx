import { useEffect } from 'react'
import { motion } from 'framer-motion'
import './Results.css'

const Results = ({ data }) => {
    const { results = [], summary = "" } = data || {};
    const safeResults = Array.isArray(results) ? results : [];
    const winner = safeResults.length > 0 ? safeResults[0] : null;

    useEffect(() => {
        const handleInput = () => {
            window.location.reload();
        };
        window.addEventListener('keydown', handleInput);
        window.addEventListener('mousedown', handleInput);
        return () => {
            window.removeEventListener('keydown', handleInput);
            window.removeEventListener('mousedown', handleInput);
        };
    }, []);

    return (
        <motion.div
            className="results-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
        >
            <div className="splatter-background">
                <div className="splat-effect s1"></div>
                <div className="splat-effect s2"></div>
                <div className="splat-effect s3"></div>
            </div>
            <div className="results-card">
                <h2>GAME OVER!</h2>
                <div className="summary-banner">{summary}</div>

                {winner && winner.definition && (
                    <div className="definition-box">
                        <strong>DEFINITION:</strong> {winner.definition}
                    </div>
                )}

                <div className="results-list">
                    {safeResults.map((res, i) => (
                        <div key={i} className="player-result-group">
                            <div className={`result-row ${i === 0 ? 'winner' : ''}`}>
                                <span className="rank">{i + 1}</span>
                                <span className="player-id">{res.player}</span>
                                <span className="player-word">{res.word}</span>
                                <span className="player-score">{res.score} pts</span>
                                {res.exceptions && res.exceptions.length > 0 && (
                                    <div className="bonus-tags">
                                        {res.exceptions.map((ex, j) => (
                                            <span key={j} className="bonus-tag">
                                                {Object.keys(ex)[0]} (+{Object.values(ex)[0]})
                                            </span>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {res.duped_by && res.duped_by.length > 0 && (
                                <div className="duped-list">
                                    {res.duped_by.map((duper, k) => (
                                        <div key={k} className="dupe-item">
                                            ↳ <em>{duper}</em> played the same word.
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}
                </div>
                <div className="next-game">Next game starting soon...</div>
            </div>
        </motion.div>
    )
}

export default Results
