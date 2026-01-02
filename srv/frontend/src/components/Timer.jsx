import { motion } from 'framer-motion'
import './Timer.css'

const Timer = ({ seconds, total }) => {
    const percentage = (seconds / total) * 100;

    return (
        <div className="timer-container">
            <div className="timer-label">TIME</div>
            <div className="timer-bar-bg">
                <motion.div
                    className="timer-bar-fill"
                    initial={{ height: '100%' }}
                    animate={{ height: `${percentage}%` }}
                    transition={{ duration: 0.5 }}
                />
            </div>
            <div className="timer-value">{seconds}s</div>
        </div>
    )
}

export default Timer
