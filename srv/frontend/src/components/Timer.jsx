import { motion } from 'framer-motion'
import './Timer.css'

const Timer = ({ seconds, total }) => {
    const percentage = (seconds / total) * 100;

    return (
        <div className="timer-container">
            <div className="timer-bar-bg">
                <motion.div
                    className="timer-bar-fill"
                    initial={{ width: '100%' }}
                    animate={{ width: `${percentage}%` }}
                    transition={{ duration: 0.5 }}
                />
            </div>
            <div className="timer-value">{seconds}s</div>
        </div>
    )
}

export default Timer
