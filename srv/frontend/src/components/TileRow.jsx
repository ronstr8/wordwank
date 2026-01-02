import Tile from './Tile'
import './TileRow.css'

const TileRow = ({ letters }) => {
    return (
        <div className="tile-row">
            {letters.map((letter, i) => (
                <Tile key={i} letter={letter} />
            ))}
        </div>
    )
}

export default TileRow
