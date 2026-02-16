import React from 'react';
import Logo from './Logo';
import { useTheme } from '../context/ThemeContext';

const TheSanctuary = ({ onEnter }) => {
    const { theme } = useTheme();

    return (
        <div className="fixed inset-0 bg-background flex flex-col items-center justify-center p-6 z-50 overflow-hidden">
            <div className="text-center z-10">
                <Logo
                    className="w-32 h-32 mx-auto mb-10"
                    theme={theme}
                    onClick={() => window.location.reload()}
                />

                <h1 className="text-3xl font-mono font-light tracking-[0.3em] text-text mb-12 uppercase">
                    Alethia: Preserving Financial Truth.
                </h1>

                <button
                    onClick={onEnter}
                    className="group relative px-12 py-4 bg-transparent border border-primary/30 rounded-none overflow-hidden transition-all duration-500 hover:border-primary"
                >
                    <span className="relative z-10 font-mono text-sm tracking-widest text-primary group-hover:text-text transition-colors uppercase">
                        Enter the Vault
                    </span>
                </button>
            </div>

            <div className="absolute bottom-10 left-10 flex gap-4 text-[10px] uppercase tracking-widest text-text-dim/30 font-mono">
                <span>Architectural Integrity</span>
                <span>•</span>
                <span>Institutional Security</span>
            </div>
        </div>
    );
};

export default TheSanctuary;
