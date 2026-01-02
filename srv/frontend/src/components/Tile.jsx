import { motion } from 'framer-motion'
import './Tile.css'

const letterValues = {
    A: 1, B: 3, C: 3, D: 2, E: 1, F: 4, G: 2, H: 4, I: 1, J: 8, K: 5, L: 1,
    M: 3, N: 1, O: 1, P: 3, Q: 10, R: 1, S: 1, T: 1, U: 2, V: 4, W: 4, X: 8,
    Y: 4, Z: 10
};

const Tile = ({ letter }) => {
    return (
        <motion.div
            className="tile-wrapper"
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
                    <span className="tile-value">{letterValues[letter] || 0}</span>
                </div>
                <div className="tile-back"></div>
            </div>
        </motion.div>
    )
}

export default Tile
