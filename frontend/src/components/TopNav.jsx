import React from 'react';
import { motion } from 'framer-motion';
import { ArrowLeft, LogOut, Shield } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import Logo from './Logo';

const TopNav = ({ onBack, onLogout, title, onSecurityClick }) => {
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="sticky top-0 z-40 bg-background/80 backdrop-blur-sm border-b border-border">
      <div className="flex items-center justify-between px-6 py-4">
        {/* Left: Back + Title */}
        <div className="flex items-center gap-6">
          <button
            onClick={onBack}
            className="flex items-center gap-2 text-text-dim hover:text-primary transition-colors duration-300 group"
          >
            <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform duration-300" />
            <span className="font-mono text-xs tracking-[0.2em] uppercase">Home</span>
          </button>

          <div className="h-4 w-px bg-border" />

          <div className="flex items-center gap-3">
            <Logo size={24} theme={theme} />
            <h1 className="font-mono text-sm tracking-[0.3em] uppercase text-text">
              {title}
            </h1>
          </div>
        </div>

        {/* Right: Theme + Security + Logout */}
        <div className="flex items-center gap-6">
          {/* Theme Toggle */}
          <div className="flex items-center gap-3">
            <span className="font-mono text-[10px] tracking-widest text-text-dim uppercase">
              {theme === 'gold' ? 'Gold' : 'Silver'}
            </span>
            <div
              onClick={toggleTheme}
              className={`relative w-10 h-5 cursor-pointer transition-colors duration-300
                         ${theme === 'gold' ? 'bg-primary/20' : 'bg-slate-400/20'}
                         border border-border flex items-center`}
            >
              <motion.div
                animate={{ x: theme === 'gold' ? 2 : 22 }}
                className={`w-4 h-4 shadow-lg ${theme === 'gold' ? 'bg-primary' : 'bg-slate-400'}`}
              />
            </div>
          </div>

          <div className="h-4 w-px bg-border" />

          {/* Security */}
          <button
            onClick={onSecurityClick}
            className="flex items-center gap-2 text-text-dim hover:text-primary transition-colors duration-300"
            title="Security & Settings"
          >
            <Shield size={18} />
            <span className="font-mono text-xs tracking-wider uppercase hidden md:block">Security</span>
          </button>

          <div className="h-4 w-px bg-border" />

          {/* Logout */}
          <button
            onClick={onLogout}
            className="flex items-center gap-2 text-text-dim hover:text-red-500 transition-colors duration-300"
          >
            <LogOut size={18} />
            <span className="font-mono text-xs tracking-wider uppercase hidden md:block">Exit</span>
          </button>
        </div>
      </div>
    </header>
  );
};

export default TopNav;
