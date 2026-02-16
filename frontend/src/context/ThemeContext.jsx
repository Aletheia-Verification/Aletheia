import React, { createContext, useContext, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const ThemeContext = createContext();

export const useTheme = () => useContext(ThemeContext);

export const ThemeProvider = ({ children }) => {
    const [theme, setTheme] = useState(() => localStorage.getItem('alethia-theme') || 'gold');
    const [ripple, setRipple] = useState(null);

    useEffect(() => {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('alethia-theme', theme);
    }, [theme]);

    const toggleTheme = (event) => {
        const nextTheme = theme === 'gold' ? 'silver' : 'gold';
        const rippleColor = nextTheme === 'silver' ? '#64748B' : '#D4AF37';

        // Calculate ripple position from event or default to bottom-left (near toggle)
        const x = event?.clientX || 40;
        const y = event?.clientY || window.innerHeight - 40;

        setRipple({ x, y, color: rippleColor });

        // Execute theme change after a slight delay to allow ripple to start
        setTimeout(() => {
            setTheme(nextTheme);
        }, 100);

        // Clear ripple after animation
        setTimeout(() => {
            setRipple(null);
        }, 800);
    };

    return (
        <ThemeContext.Provider value={{ theme, toggleTheme }}>
            {children}
            <AnimatePresence>
                {ripple && (
                    <motion.div
                        initial={{ scale: 0, opacity: 1, x: ripple.x, y: ripple.y }}
                        animate={{
                            scale: 15, // Scale enough to cover screen
                            opacity: 0,
                            transition: { duration: 0.8, ease: "easeOut" }
                        }}
                        exit={{ opacity: 0 }}
                        style={{
                            position: 'fixed',
                            left: -50, // Offset to center on x,y
                            top: -50,
                            width: 100,
                            height: 100,
                            borderRadius: '50%',
                            backgroundColor: ripple.color,
                            zIndex: 9999,
                            pointerEvents: 'none',
                            transformOrigin: 'center'
                        }}
                    />
                )}
            </AnimatePresence>
        </ThemeContext.Provider>
    );
};
