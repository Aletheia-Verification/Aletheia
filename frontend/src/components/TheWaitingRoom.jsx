import React from 'react';
import { motion } from 'framer-motion';
import { ShieldAlert, LogOut } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import Logo from './Logo';

const TheWaitingRoom = () => {
    const { theme } = useTheme();

    return (
        <div className="fixed inset-0 bg-background flex items-center justify-center p-6 z-[60]">
            {/* Darkened Overlay */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-md" />

            <motion.div
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="w-full max-w-2xl bg-surface/40 backdrop-blur-2xl border border-primary/30 rounded-3xl p-12 text-center shadow-[0_0_50px_rgba(212,175,55,0.15)] relative z-10 animate-pulse-gold"
            >
                <div className="flex flex-col items-center mb-8">
                    <Logo
                        className="w-32 h-32 mx-auto mb-10"
                        theme={theme}
                        onClick={() => window.location.reload()}
                    />
                    <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                        <ShieldAlert className="text-primary w-6 h-6" />
                    </div>
                </div>

                <h2 className="text-2xl font-mono font-bold tracking-widest text-text mb-6 uppercase">
                    Security Review in Progress
                </h2>

                <div className="space-y-4 text-text-dim max-w-md mx-auto leading-relaxed">
                    <p className="text-sm">
                        Access to the Alethia Engine is restricted to verified institutions.
                    </p>
                    <p className="text-xs opacity-60">
                        Our security architects are currently validating your institutional credentials.
                        You will be notified via corporate channel once authorization is granted.
                    </p>
                </div>

                <div className="mt-12 pt-8 border-t border-border/50 flex flex-col items-center gap-6">
                    <button
                        onClick={() => {
                            localStorage.removeItem('alethia_token');
                            window.location.reload();
                        }}
                        className="flex items-center gap-2 text-[10px] font-mono uppercase tracking-widest text-text-dim hover:text-primary transition-colors"
                    >
                        <LogOut size={14} /> Exit to Sanctuary
                    </button>
                    <span className="text-[10px] uppercase tracking-widest text-primary/40 font-mono">
                        Alethia Security Protocol v2.5.0
                    </span>
                </div>
            </motion.div>
        </div>
    );
};

export default TheWaitingRoom;
