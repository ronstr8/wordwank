import { useEffect, useRef, useState } from 'react';

const useSound = () => {
    const [isMuted, setIsMuted] = useState(() => {
        const saved = localStorage.getItem('wordwank_muted');
        return saved === 'true';
    });

    const [isAmbienceEnabled, setIsAmbienceEnabled] = useState(() => {
        const saved = localStorage.getItem('wordwank_ambience_enabled');
        return saved !== 'false'; // Default to true
    });

    const soundsRef = useRef({});

    useEffect(() => {
        // Preload all sounds
        soundsRef.current = {
            placement: new Audio('/sounds/placement.mp3'),
            buzzer: new Audio('/sounds/buzzer.mp3'),
            bigsplat: new Audio('/sounds/bigsplat.mp3'),
            ambience: new Audio('/sounds/ambience.mp3')
        };

        // Configure ambience for looping
        soundsRef.current.ambience.loop = true;
        soundsRef.current.ambience.volume = 0.3; // Subtle background

        // Lower volume for quick sounds
        soundsRef.current.placement.volume = 0.4;
        soundsRef.current.buzzer.volume = 0.5;
        soundsRef.current.bigsplat.volume = 0.7;

        // Auto-start ambience if conditions met
        if (!isMuted && isAmbienceEnabled) {
            soundsRef.current.ambience.play().catch(() => {
                console.debug('Autoplay prevented - waiting for interaction');
            });
        }

        return () => {
            // Cleanup on unmount
            Object.values(soundsRef.current).forEach(audio => {
                audio.pause();
                audio.src = '';
            });
        };
    }, []);

    const play = (soundName) => {
        if (isMuted) return;

        const sound = soundsRef.current[soundName];
        if (!sound) return;

        // Reset and play (allows rapid repeated sounds)
        sound.currentTime = 0;
        sound.play().catch(err => {
            // Ignore autoplay restrictions
            console.debug('Audio play prevented:', err);
        });
    };

    const startAmbience = () => {
        if (isMuted || !isAmbienceEnabled) return;
        soundsRef.current.ambience?.play().catch(() => { });
    };

    const stopAmbience = () => {
        soundsRef.current.ambience?.pause();
    };

    const toggleAmbience = () => {
        setIsAmbienceEnabled(prev => {
            const newValue = !prev;
            localStorage.setItem('wordwank_ambience_enabled', newValue.toString());

            if (newValue && !isMuted) {
                startAmbience();
            } else {
                stopAmbience();
            }
            return newValue;
        });
    };

    const toggleMute = () => {
        setIsMuted(prev => {
            const newValue = !prev;
            localStorage.setItem('wordwank_muted', newValue.toString());

            // Stop/Start ambience based on master mute and current state
            if (newValue) {
                stopAmbience();
            } else if (isAmbienceEnabled) {
                startAmbience();
            }

            return newValue;
        });
    };

    return { play, startAmbience, stopAmbience, toggleAmbience, toggleMute, isMuted, isAmbienceEnabled };
};

export default useSound;
