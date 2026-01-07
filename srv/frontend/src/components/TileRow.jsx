import Tile from './Tile'
import './TileRow.css'

const TileRow = ({ letters = [] }) => {
    // Always show 7 slots, fill with empty strings if needed
    const displayLetters = [...letters];
    while (displayLetters.length < 7) {
        displayLetters.push('');
    }

    return (
        <div className="tile-row">
            {displayLetters.map((letter, i) => (
                <Tile key={i} letter={letter} />
            ))}
        </div>
    )
}

export default TileRow
