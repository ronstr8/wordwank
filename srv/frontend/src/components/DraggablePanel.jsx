import { useState, useEffect } from 'react';
import './Panel.css';

const DraggablePanel = ({ title, children, id, initialPos, initialSize = { width: 300, height: 250 }, onClose, storageKey }) => {
    // Load saved preferences from localStorage
    const loadFromStorage = () => {
        if (!storageKey) return { pos: initialPos, size: initialSize };

        try {
            const saved = localStorage.getItem(`panel_${storageKey}`);
            if (saved) {
                const { position, size } = JSON.parse(saved);
                return {
                    pos: position || initialPos,
                    size: size || initialSize
                };
            }
        } catch (e) {
            console.error('Failed to load panel preferences:', e);
        }
        return { pos: initialPos, size: initialSize };
    };

    const saved = loadFromStorage();
    const [pos, setPos] = useState(saved.pos);
    const [size, setSize] = useState(saved.size);
    const [isDragging, setIsDragging] = useState(false);
    const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

    // Save to localStorage when position or size changes
    useEffect(() => {
        if (!storageKey) return;

        try {
            localStorage.setItem(`panel_${storageKey}`, JSON.stringify({
                position: pos,
                size: size
            }));
        } catch (e) {
            console.error('Failed to save panel preferences:', e);
        }
    }, [pos, size, storageKey]);

    const onMouseDown = (e) => {
        // Don't start drag if clicking close button
        if (e.target.classList.contains('panel-close-btn') || e.target.closest('.panel-close-btn')) {
            return;
        }
        if (e.target.classList.contains('panel-header') || e.target.closest('.panel-header')) {
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
                <span>{title}</span>
                {onClose && (
                    <button className="panel-close-btn" onClick={onClose}>×</button>
                )}
            </div>
            <div className="panel-body">
                {children}
            </div>
            <div className="resize-handle resize-handle-br" onMouseDown={(e) => {
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
            <div className="resize-handle resize-handle-bl" onMouseDown={(e) => {
                e.stopPropagation();
                const startWidth = size.width;
                const startHeight = size.height;
                const startX = e.clientX;
                const startY = e.clientY;
                const startPosX = pos.x;

                const onMouseMove = (moveEvent) => {
                    const deltaX = moveEvent.clientX - startX;
                    const newWidth = Math.max(200, startWidth - deltaX);
                    setSize({
                        width: newWidth,
                        height: Math.max(150, startHeight + (moveEvent.clientY - startY))
                    });
                    // Move panel right when resizing from left to maintain right edge position
                    setPos({
                        x: startPosX + (startWidth - newWidth),
                        y: pos.y
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
