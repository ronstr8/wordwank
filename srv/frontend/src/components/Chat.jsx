import { useState } from 'react'
import { useTranslation } from 'react-i18next'
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
                {(messages || []).map((msg, i) => (
                    <div key={i} className="chat-msg">
                        <span className="chat-sender">{msg.senderName || msg.sender}:</span>
                        <span className="chat-text">{msg.sender === 'SYSTEM' ? t(msg.text) : msg.text}</span>
                    </div>
                ))}
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
