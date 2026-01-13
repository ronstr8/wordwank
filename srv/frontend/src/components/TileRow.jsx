import Tile from './Tile'
import './TileRow.css'

const TileRow = ({ letters = [] }) => {
    // Show exactly the number of letters provided
    return (
        <div className="tile-row">
            {letters.map((letter, i) => (
                <Tile key={i} letter={letter} />
            ))}
        </div>
    )
}

export default TileRow
