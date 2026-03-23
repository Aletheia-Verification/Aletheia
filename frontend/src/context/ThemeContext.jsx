import React, { createContext, useContext, useState, useEffect } from 'react';

const ThemeContext = createContext();

export const useTheme = () => useContext(ThemeContext);

export const ThemeProvider = ({ children }) => {
    const [theme, setTheme] = useState('gold');
    const isDark = false;

    useEffect(() => {
        document.documentElement.setAttribute('data-theme', theme);
        document.documentElement.setAttribute('data-dark', 'false');
        localStorage.removeItem('alethia-dark');
    }, [theme]);

    const toggleTheme = () => {
        setTheme(prev => prev === 'gold' ? 'silver' : 'gold');
    };

    const toggleDark = () => {};

    return (
        <ThemeContext.Provider value={{ theme, toggleTheme, isDark, toggleDark }}>
            {children}
        </ThemeContext.Provider>
    );
};
