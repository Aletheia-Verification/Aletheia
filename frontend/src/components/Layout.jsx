import React, { useState } from 'react';
import Sidebar from './Sidebar';
import { useTheme } from '../context/ThemeContext';

const Layout = ({ children, activeTab, setActiveTab, onLogout }) => {
    const { theme } = useTheme();

    return (
        <div className="flex min-h-screen bg-background text-text transition-colors duration-500">
            <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} onLogout={onLogout} />
            <main className="flex-1 ml-[64px] relative min-h-screen overflow-y-auto">
                {/* Background Decorative Element */}
                <div className="fixed inset-0 pointer-events-none overflow-hidden opacity-20">
                    <div className="absolute top-[-10%] right-[-10%] w-[50%] h-[50%] bg-primary/20 rounded-full blur-[120px]" />
                    <div className="absolute bottom-[-10%] left-[-10%] w-[40%] h-[40%] bg-primary/10 rounded-full blur-[100px]" />
                </div>

                <div className="relative z-10">
                    {children}
                </div>
            </main>
        </div>
    );
};

export default Layout;
