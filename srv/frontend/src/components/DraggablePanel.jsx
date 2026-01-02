import { useState, useEffect } from 'react';
import './Panel.css';

const DraggablePanel = ({ title, children, id, initialPos }) => {
    const [pos, setPos] = useState(initialPos);
    const [size, setSize] = useState({ width: 300, height: 250 });
    const [isDragging, setIsDragging] = useState(false);
    const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

    const onMouseDown = (e) => {
        if (e.target.classList.contains('panel-header')) {
            setIsDragging(true);
            setDragStart({
                x: e.clientX - pos.x,
                y: e.clientY - pos.y
            });
        }
    };

    useEffect(() => {
        const onMouseMove = (e) => {
            if (!isDragging) return;
            setPos({
                x: e.clientX - dragStart.x,
                y: e.clientY - dragStart.y
            });
        };

        const onMouseUp = () => {
            setIsDragging(false);
        };

        if (isDragging) {
            window.addEventListener('mousemove', onMouseMove);
            window.addEventListener('mouseup', onMouseUp);
        }

        return () => {
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);
        };
    }, [isDragging, dragStart]);

    return (
        <div
            className={`panel-draggable ${isDragging ? 'dragging' : ''}`}
            style={{
                left: pos.x,
                top: pos.y,
                width: size.width,
                height: size.height,
                position: 'fixed',
                zIndex: isDragging ? 2000 : 100
            }}
            onMouseDown={onMouseDown}
        >
            <div className="panel-header">
                {title}
            </div>
            <div className="panel-body">
                {children}
            </div>
            <div className="resize-handle" onMouseDown={(e) => {
                e.stopPropagation();
                const startWidth = size.width;
                const startHeight = size.height;
                const startX = e.clientX;
                const startY = e.clientY;

                const onMouseMove = (moveEvent) => {
                    setSize({
                        width: Math.max(200, startWidth + (moveEvent.clientX - startX)),
                        height: Math.max(150, startHeight + (moveEvent.clientY - startY))
                    });
                };
                const onMouseUp = () => {
                    window.removeEventListener('mousemove', onMouseMove);
                    window.removeEventListener('mouseup', onMouseUp);
                };
                window.addEventListener('mousemove', onMouseMove);
                window.addEventListener('mouseup', onMouseUp);
            }} />
        </div>
    );
};

export default DraggablePanel;
