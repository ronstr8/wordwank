import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import MessageList from './MessageList'
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
            <MessageList messages={messages} />
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
