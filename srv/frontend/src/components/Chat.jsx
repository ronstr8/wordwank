import { useState } from 'react'
import { useTranslation, Trans } from 'react-i18next'
import './Panel.css'

const Chat = ({ messages, onSendMessage }) => {
    const { t } = useTranslation();
    const [input, setInput] = useState('')

    const handleSend = (e) => {
        e.preventDefault();
        if (input.trim()) {
            onSendMessage(input);
            setInput('');
        }
    };

    return (
        <>
            <div className="panel-content chat-history">
                {(messages || []).map((msg, i) => {
                    if (msg.isSeparator) {
                        return <div key={i} className="chat-separator"><hr /></div>;
                    }
                    const isSystem = msg.isSystem || msg.sender === 'SYSTEM';
                    return (
                        <div key={i} className={`chat-msg ${isSystem ? 'system-msg' : ''}`}>
                            {isSystem ? (
                                <>
                                    <span className="chat-icon">🤖 </span>
                                    <span className="chat-text">{msg.sender === 'SYSTEM' ? t(msg.text) : msg.text}</span>
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
            <form onSubmit={handleSend} className="chat-input-area">
                <input
                    type="text"
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    placeholder={t('app.chat_placeholder')}
                />
                <button type="submit">{t('app.chat_send')}</button>
            </form>
        </>
    )
}

export default Chat
