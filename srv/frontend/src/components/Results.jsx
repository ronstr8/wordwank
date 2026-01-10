import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import './Results.css'

const Results = ({ data, onClose, playerNames = {} }) => {
    const { t } = useTranslation();
    const { results = [], summary = "" } = data || {};
    const safeResults = Array.isArray(results) ? results : [];
    const winner = safeResults.length > 0 ? safeResults[0] : null;
    const [showDefinition, setShowDefinition] = useState(false);

    useEffect(() => {
        const handleKeydown = () => {
            if (showDefinition) {
                setShowDefinition(false);
            } else if (onClose) {
                onClose();
            }
        };

        window.addEventListener('keydown', handleKeydown);
        return () => window.removeEventListener('keydown', handleKeydown);
    }, [onClose, showDefinition]);

    const handleOverlayClick = () => {
        if (showDefinition) {
            setShowDefinition(false);
        } else if (onClose) {
            onClose();
        }
    };

    return (
        <motion.div
            className="results-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            onClick={handleOverlayClick}
        >
            <div className="splatter-background">
                <div className="splat-effect s1"></div>
                <div className="splat-effect s2"></div>
                <div className="splat-effect s3"></div>
            </div>
            <div className="results-card" onClick={(e) => !showDefinition && e.stopPropagation()}>
                <h2>{t('results.title')}!</h2>
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
                            {t('results.wait_what_does', { word: winner.word.toUpperCase() })}
                        </button>
                    </div>
                )}

                <div className="results-list">
                    {safeResults.length === 0 ? (
                        <div className="no-plays-msg">
                            <div className="no-plays-icon">💨</div>
                            <h3>{t('results.no_plays_round')}</h3>
                            <p>{t('results.riveting')}</p>
                        </div>
                    ) : (
                        safeResults.map((res, i) => (
                            <div key={i} className="player-result-group">
                                <div className={`result-row ${i === 0 ? 'winner' : ''}`}>
                                    <span className="rank">{i + 1}</span>
                                    <span className="player-id">{playerNames[res.player] || res.player}</span>
                                    <span className="player-word">{res.word}</span>
                                    <span className="player-score">{res.score} {t('results.score').toLowerCase()}</span>
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
                                                ↳ <em>{duper}</em> {t('results.played_same_word')}
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                        ))
                    )}
                </div>
                <div className="next-game">{t('results.next_game_soon')}</div>
            </div>

            {showDefinition && winner && (
                <div className="definition-modal-overlay" onClick={(e) => {
                    e.stopPropagation();
                    setShowDefinition(false);
                }}>
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
    );
}

export default Results
