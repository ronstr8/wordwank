import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import './Results.css'

const Results = ({ data, onClose, playerNames = {} }) => {
    const { results = [], summary = "" } = data || {};
    const safeResults = Array.isArray(results) ? results : [];
    const winner = safeResults.length > 0 ? safeResults[0] : null;
    const [showDefinition, setShowDefinition] = useState(false);

    useEffect(() => {
        const handleInput = (e) => {
            // Only prevent closing if clicking inside the definition modal content
            if (showDefinition && e.target.closest('.definition-modal-card')) return;
            if (onClose) onClose();
        };
        window.addEventListener('keydown', handleInput);
        window.addEventListener('mousedown', handleInput);
        return () => {
            window.removeEventListener('keydown', handleInput);
            window.removeEventListener('mousedown', handleInput);
        };
    }, [onClose, showDefinition]);

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
                    <div className="definition-prompt">
                        <button
                            className="meaning-btn"
                            onClick={(e) => {
                                e.stopPropagation();
                                setShowDefinition(true);
                            }}
                        >
                            Wait, what does "{winner.word.toUpperCase()}" mean?
                        </button>
                    </div>
                )}

                <div className="results-list">
                    {safeResults.map((res, i) => (
                        <div key={i} className="player-result-group">
                            <div className={`result-row ${i === 0 ? 'winner' : ''}`}>
                                <span className="rank">{i + 1}</span>
                                <span className="player-id">{playerNames[res.player] || res.player}</span>
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
            {showDefinition && winner && (
                <div className="definition-modal-overlay" onClick={() => setShowDefinition(false)}>
                    <motion.div
                        className="definition-modal-card"
                        initial={{ scale: 0.8, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <header className="modal-header">
                            <h3>{winner.word.toUpperCase()}</h3>
                            <button className="close-modal" onClick={() => setShowDefinition(false)}>×</button>
                        </header>
                        <div className="modal-body scrollable">
                            <pre className="definition-text">
                                {winner.definition}
                            </pre>
                        </div>
                    </motion.div>
                </div>
            )}
        </motion.div>
    )
}

export default Results
