import { motion } from 'framer-motion'
import './Tile.css'

const Tile = ({ letter, value, disabled }) => {
    const isBlankPlayed = (letter === letter.toLowerCase() && letter !== '_' && letter !== '');
    const displayValue = isBlankPlayed ? 0 : (value !== undefined ? value : '');
    return (
        <motion.div
            className={`tile-wrapper ${isBlankPlayed ? 'is-blank' : ''} ${disabled ? 'disabled' : ''}`}
            initial={{ rotateY: 180 }}
            animate={{ rotateY: 0 }}
            transition={{
                type: "spring",
                stiffness: 260,
                damping: 20,
                delay: Math.random() * 0.5
            }}
        >
            <div className="tile-inner">
                <div className="tile-front">
                    <span className="tile-letter">{letter}</span>
                    <span className="tile-value">{displayValue}</span>
                </div>
                <div className="tile-back"></div>
            </div>
        </motion.div>
    )
}

export default Tile
