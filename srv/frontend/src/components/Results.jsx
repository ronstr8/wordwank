import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import './Results.css'

const Results = ({ data, onClose, playerNames = {}, isFocusMode = false }) => {
    const { t } = useTranslation();
    const { results = [], summary = "", is_solo = false } = data || {};
    const safeResults = Array.isArray(results) ? results : [];
    const [activeWord, setActiveWord] = useState(null);

    useEffect(() => {
        const handleKeydown = () => {
            if (activeWord) {
                setActiveWord(null);
            } else if (onClose) {
                onClose();
            }
        };

        window.addEventListener('keydown', handleKeydown);
        return () => window.removeEventListener('keydown', handleKeydown);
    }, [onClose, activeWord]);

    const handleOverlayClick = () => {
        if (!activeWord && onClose) {
            onClose();
        }
    };

    const handleCardClick = (e) => {
        if (!activeWord && onClose) {
            onClose();
        }
    };

    return (
        <motion.div
            className={`results-overlay ${isFocusMode ? 'focus-mode' : ''}`}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            onClick={handleOverlayClick}
        >
            <div className="splatter-background">
                <div className="splat-effect s1"></div>
                {!isFocusMode && (
                    <>
                        <div className="splat-effect s2"></div>
                        <div className="splat-effect s3"></div>
                    </>
                )}
            </div>
            <div className="results-card" onClick={handleCardClick}>
                {!isFocusMode && <h2>{t('results.title')}!</h2>}
                {isFocusMode && <div className="focus-results-label">Round Over</div>}

                <div className="results-list">
                    {safeResults.length === 0 ? (
                        <div className="no-plays-msg">
                            <div className="no-plays-icon">💨</div>
                            <h3>{t('results.no_plays_round')}</h3>
                            <p>{t('results.riveting')}</p>
                        </div>
                    ) : (
                        safeResults.map((res, i) => (
                            <div key={i} className={`player-result-bubble ${i === 0 ? 'winner' : ''}`}>
                                <div className="bubble-header">
                                    <span className="rank">{i + 1}</span>
                                    <span className="player-id">{playerNames[res.player] || res.player}</span>
                                    <span className="player-word">{res.word}</span>
                                    <span className="player-score">{res.score} {t('results.score').toLowerCase()}</span>
                                </div>
                                <div className="bubble-details">
                                    <div className="detail-item">
                                        <em>{t('results.base_score', 'Base Score')}:</em> {res.base_score || 0}
                                    </div>
                                    {res.bonuses && res.bonuses.map((bonus, j) => {
                                        const bonusType = Object.keys(bonus)[0];
                                        const bonusValue = Object.values(bonus)[0];
                                        return (
                                            <div key={j} className="detail-item">
                                                <em>{bonusType}:</em> +{bonusValue}
                                            </div>
                                        );
                                    })}
                                    {res.duped_by && res.duped_by.map((duper, k) => (
                                        <div key={k} className="detail-item dupe-detail">
                                            ↳ {duper.name} {t('results.duped_you', 'duplicated you')} (+{duper.bonus})
                                        </div>
                                    ))}
                                    {!!res.is_dupe && (
                                        <div className="detail-item dupe-warning">
                                            ⚠️ {t('results.duplicate_penalty', '0 points (Duplicate)')}
                                        </div>
                                    )}
                                    {res.definition && (
                                        <button
                                            className="definition-link"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                setActiveWord({ word: res.word, text: res.definition });
                                            }}
                                        >
                                            📖 {t('results.definition_link')}
                                        </button>
                                    )}
                                </div>
                            </div>
                        ))
                    )}
                </div>
                {is_solo && (
                    <div className="solo-wanker-note">
                        {t('results.solo_wanker')}
                    </div>
                )}
                <div className="next-game">{t('results.next_game_soon')}</div>
            </div>

            {activeWord && (
                <div className="definition-modal-overlay" onClick={(e) => {
                    e.stopPropagation();
                    setActiveWord(null);
                }}>
                    <motion.div
                        className="definition-modal-card"
                        initial={{ scale: 0.8, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <header className="modal-header">
                            <h3>{activeWord.word.toUpperCase()}</h3>
                            <button className="close-modal" onClick={(e) => {
                                e.stopPropagation();
                                setActiveWord(null);
                            }}>×</button>
                        </header>
                        <div className="modal-body scrollable">
                            <pre className="definition-text">
                                {activeWord.text}
                            </pre>
                        </div>
                    </motion.div>
                </div>
            )}
        </motion.div>
    );
}

export default Results
