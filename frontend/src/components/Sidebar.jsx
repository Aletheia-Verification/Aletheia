import React, { useState } from 'react';
import {
    LayoutDashboard,
    Cpu,
    User,
    LogOut,
    ChevronRight
} from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import Logo from './Logo';

const SidebarItem = ({ icon: Icon, label, active, onClick, expanded }) => {
    return (
        <button
            onClick={onClick}
            className={`
        w-full flex items-center gap-4 px-4 py-3 rounded-xl transition-all duration-300
        ${active
                    ? 'bg-primary/10 text-primary border border-primary/20'
                    : 'text-text-dim hover:bg-surface-highlight hover:text-text'}
      `}
        >
            <div className="flex-shrink-0">
                <Icon size={20} strokeWidth={active ? 2.5 : 2} />
            </div>
            {expanded && (
                <span className="text-sm font-medium whitespace-nowrap fade-in">
                    {label}
                </span>
            )}
        </button>
    );
};

const Sidebar = ({ activeTab, setActiveTab, onLogout }) => {
    const [isExpanded, setIsExpanded] = useState(false);
    const { theme, toggleTheme } = useTheme();

    const menuItems = [
        { id: 'vault', icon: LayoutDashboard, label: 'Vault' },
        { id: 'engine', icon: Cpu, label: 'The Engine' },
        { id: 'security', icon: User, label: 'Security' },
    ];

    return (
        <aside
            onMouseEnter={() => setIsExpanded(true)}
            onMouseLeave={() => setIsExpanded(false)}
            className="fixed left-0 top-0 h-screen bg-background border-r border-border z-50 flex flex-col py-6 transition-all duration-300 shadow-2xl overflow-hidden"
            style={{ width: isExpanded ? 200 : 64 }}
        >
            {/* Top Logo & Branding */}
            <div
                onClick={() => setActiveTab('vault')}
                className="flex items-center px-4 mb-10 overflow-hidden cursor-pointer group"
            >
                <Logo className="w-8 h-8 flex-shrink-0 group-hover:scale-105 transition-transform" theme={theme} />
                {isExpanded && (
                    <span className="ml-4 font-mono font-bold tracking-widest text-primary text-xl group-hover:text-text transition-colors fade-in">
                        ALETHIA
                    </span>
                )}
            </div>

            {/* Navigation */}
            <nav className="flex-1 px-2 space-y-2">
                {menuItems.map((item) => (
                    <SidebarItem
                        key={item.id}
                        icon={item.icon}
                        label={item.label}
                        active={activeTab === item.id}
                        onClick={() => setActiveTab(item.id)}
                        expanded={isExpanded}
                    />
                ))}
            </nav>

            {/* Bottom Actions */}
            <div className="px-2 space-y-6">
                {/* Theme Toggle Slider */}
                <div className="px-4 py-2">
                    {isExpanded && (
                        <span className="text-[10px] uppercase tracking-widest text-text-dim mb-2 block">
                            Surface Mode
                        </span>
                    )}
                    <div
                        onClick={toggleTheme}
                        className={`
              relative w-10 h-5 rounded-full cursor-pointer transition-colors duration-300
              ${theme === 'gold' ? 'bg-primary/20' : 'bg-slate-400/20'}
              border border-border flex items-center
            `}
                    >
                        <div
                            className={`w-4 h-4 rounded-full shadow-lg ${theme === 'gold' ? 'bg-primary' : 'bg-slate-400'}`}
                            style={{ transform: `translateX(${theme === 'gold' ? 2 : 22}px)`, transition: 'transform 150ms ease' }}
                        />
                    </div>
                </div>

                {/* Logout */}
                <button
                    onClick={onLogout}
                    className="w-full flex items-center gap-4 px-4 py-3 rounded-xl text-text-dim hover:text-red-500 hover:bg-red-500/5 transition-all"
                >
                    <LogOut size={20} />
                    {isExpanded && (
                        <span className="text-sm font-medium">Logout</span>
                    )}
                </button>
            </div>
        </aside>
    );
};

export default Sidebar;
