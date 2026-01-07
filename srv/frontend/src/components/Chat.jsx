import { useState } from 'react'
import './Panel.css'

const Chat = ({ messages, onSendMessage }) => {
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
                        <span className="chat-sender">{msg.sender}:</span>
                        <span className="chat-text">{msg.text}</span>
                    </div>
                ))}
            </div>
            <form onSubmit={handleSend} className="chat-input-area">
                <input
                    type="text"
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    placeholder="Type a message..."
                />
                <button type="submit">SEND</button>
            </form>
        </>
    )
}

export default Chat
