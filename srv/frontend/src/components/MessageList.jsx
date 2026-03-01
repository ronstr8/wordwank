import { useEffect, useRef } from 'react'
import { useTranslation, Trans } from 'react-i18next'
import './Panel.css'

const MessageList = ({ messages }) => {
    const { t } = useTranslation();
    const scrollRef = useRef(null);
    const isAtBottom = useRef(true);

    const scrollToBottom = (force = false) => {
        if (scrollRef.current && (force || isAtBottom.current)) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    };

    const handleScroll = () => {
        if (scrollRef.current) {
            const { scrollTop, scrollHeight, clientHeight } = scrollRef.current;
            // Use a 50px threshold for being "at the bottom"
            const atBottom = scrollHeight - scrollTop - clientHeight < 50;
            isAtBottom.current = atBottom;
        }
    };

    // Scroll to bottom on initial mount
    useEffect(() => {
        scrollToBottom(true);
    }, []);

    // Scroll on new messages only if we were already at the bottom
    useEffect(() => {
        requestAnimationFrame(() => scrollToBottom());
    }, [messages]);

    const getSystemIcon = (msg) => {
        if (msg.type === 'results' || msg.type === 'results_table') return '🏆';
        const text = msg.text || '';
        if (text.includes('start wanking')) return '🏁';
        if (text.includes('played a word')) return '📝';
        if (text.includes('won with') || text.includes('won the round')) return '🏆';
        return '🤖';
    };

    const renderResultsTable = (results) => {
        if (!results || results.length === 0) return null;
        return (
            <table className="results-table">
                <tbody>
                    {results.map((r, idx) => (
                        <tr key={idx}>
                            <td className="col-player">{r.nickname || r.player || 'Anonymous'}</td>
                            <td className="col-word">{r.word || '???'}</td>
                            <td className={`col-score ${r.is_dupe ? 'is-dupe' : ''}`}>
                                {r.is_dupe ? t('results.duplicate_penalty') || 'Duplicate!' : r.score}
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        );
    };

    return (
        <div
            className="panel-content chat-history"
            ref={scrollRef}
            onScroll={handleScroll}
            style={{ overflowY: 'auto' }}
        >
            {(messages || []).map((msg, i) => {
                if (msg.isSeparator) {
                    return <div key={i} className="chat-separator"><hr /></div>;
                }
                const isSystem = msg.isSystem || msg.sender === 'SYSTEM';
                const icon = isSystem ? getSystemIcon(msg) : null;

                // Strip leading emoji from text if we are already showing one as an icon
                let displayWeightText = msg.text;
                if (isSystem && icon) {
                    displayWeightText = displayWeightText.replace(/^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*/u, '');
                }

                return (
                    <div key={i} className={`chat-msg ${isSystem ? 'system-msg' : ''}`}>
                        {isSystem ? (
                            <>
                                <span className="chat-icon">{icon} </span>
                                <div className="system-content">
                                    <span className="chat-text" style={{ whiteSpace: 'pre-wrap' }}>{displayWeightText}</span>
                                    {msg.type === 'results_table' && renderResultsTable(msg.data)}
                                </div>
                            </>
                        ) : (
                            <Trans
                                t={t}
                                i18nKey="app.chat_format"
                                values={{ player: msg.senderName || msg.sender, text: msg.text }}
                                components={{ v: <span className="chat-sender" /> }}
                            />
                        )}
                    </div>
                );
            })}
        </div>
    );
};

export default MessageList;
