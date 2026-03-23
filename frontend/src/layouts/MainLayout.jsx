import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Menu } from 'lucide-react';
import Sidebar from '../components/Sidebar';
import { useColors, LIGHT } from '../hooks/useColors';
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts';

const MainLayout = () => {
    const C = useColors() || LIGHT;
    const [sidebarOpen, setSidebarOpen] = useState(false);

    useKeyboardShortcuts({
        onEscape: () => { setSidebarOpen(false); },
    });

    return (
        <div className="flex min-h-screen" style={{ backgroundColor: C.bgAlt }}>
            <Sidebar
                isOpen={sidebarOpen}
                onClose={() => setSidebarOpen(false)}
            />
            <main className="flex-1 min-h-screen ml-0 md:ml-[240px]">
                {/* Mobile header with hamburger — hidden on desktop */}
                <div className="md:hidden flex items-center gap-3 px-4 py-3 border-b border-gray-200">
                    <button
                        onClick={() => setSidebarOpen(true)}
                        className="p-1 transition-colors duration-150 hover:bg-gray-100"
                    >
                        <Menu size={20} strokeWidth={1.5} style={{ color: '#1B2A4A' }} />
                    </button>
                    <span className="text-[10px] tracking-[0.25em] uppercase font-medium mx-auto" style={{ color: '#1B2A4A' }}>
                        Aletheia
                    </span>
                </div>
                <div className="p-3 md:p-6">
                    <Outlet />
                </div>
            </main>
        </div>
    );
};

export default MainLayout;
