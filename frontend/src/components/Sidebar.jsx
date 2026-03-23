import { useState } from 'react';
import { NavLink } from 'react-router-dom';
import {
    Cpu,
    GitCompareArrows,
    Activity,
    Grid3X3,
    Settings,
    Skull,
    FileJson,
    Workflow,
    ChevronDown,
} from 'lucide-react';
import { useColors, LIGHT } from '../hooks/useColors';

const MAIN_ITEMS = [
    { to: '/analyze', icon: Cpu, label: 'Analyze', shortcut: '1' },
    { to: '/verify', icon: GitCompareArrows, label: 'Verify', shortcut: '2' },
];

const ADVANCED_ITEMS = [
    { to: '/portfolio', icon: Grid3X3, label: 'Portfolio', shortcut: '3' },
    { to: '/compiler-matrix', icon: Settings, label: 'Compiler Matrix', shortcut: '4' },
    { to: '/dead-code', icon: Skull, label: 'Dead Code', shortcut: '5' },
    { to: '/sbom', icon: FileJson, label: 'SBOM', shortcut: '6' },
    { to: '/jcl', icon: Workflow, label: 'JCL', shortcut: '7' },
    { to: '/trace', icon: Activity, label: 'Trace', shortcut: '8' },
];

const Sidebar = ({ isOpen, onClose }) => {
    const C = useColors() || LIGHT;
    const [advancedOpen, setAdvancedOpen] = useState(false);

    const navClass = ({ isActive }) =>
        `group flex items-center gap-3 px-5 py-2.5 text-[13px] transition-all duration-150 border-l-2 ${
            isActive
                ? 'font-medium border-[#C9A84C]'
                : 'border-transparent'
        }`;

    const navStyle = (isActive) => ({
        color: isActive ? C.navy : C.muted,
        backgroundColor: isActive ? C.bgAlt : 'transparent',
    });

    const renderItem = (item) => (
        <NavLink
            key={item.to}
            to={item.to}
            className={navClass}
            style={({ isActive }) => navStyle(isActive)}
            onClick={onClose}
        >
            <item.icon size={18} strokeWidth={1.5} />
            <span className="flex-1">{item.label}</span>
            {item.shortcut && (
                <span
                    className="text-[9px] font-mono opacity-0 group-hover:opacity-100 transition-opacity duration-150 hidden md:inline"
                    style={{ color: C.muted }}
                >
                    ^{item.shortcut}
                </span>
            )}
        </NavLink>
    );

    return (
        <>
            {/* Mobile backdrop */}
            {isOpen && (
                <div
                    className="fixed inset-0 bg-black/50 z-30 md:hidden"
                    onClick={onClose}
                />
            )}
            <aside
                className={`
                    fixed left-0 top-0 h-screen flex flex-col
                    transition-transform duration-150
                    ${isOpen ? 'translate-x-0' : '-translate-x-full'}
                    md:translate-x-0
                `}
                style={{
                    width: 240,
                    backgroundColor: '#FFFFFF',
                    borderRight: `1px solid ${C.border}`,
                    zIndex: 40,
                }}
            >
                {/* Header spacer */}
                <div
                    className="px-5 py-3"
                    style={{ borderBottom: `1px solid ${C.border}` }}
                >
                    <span className="text-[10px] tracking-[0.2em] uppercase font-semibold" style={{ color: C.navy }}>Aletheia</span>
                </div>

                {/* Main nav */}
                <nav className="flex-1 overflow-y-auto py-2">
                    {MAIN_ITEMS.map(renderItem)}

                    {/* Advanced toggle */}
                    <button
                        onClick={() => setAdvancedOpen(!advancedOpen)}
                        className="w-full flex items-center gap-3 px-5 py-2.5 text-[12px] mt-2 transition-all duration-150"
                        style={{ color: C.muted }}
                    >
                        <ChevronDown
                            size={14}
                            strokeWidth={1.5}
                            className={`transition-transform duration-150 ${advancedOpen ? 'rotate-180' : ''}`}
                        />
                        <span>Advanced</span>
                    </button>

                    {advancedOpen && (
                        <div className="pb-1">
                            {ADVANCED_ITEMS.map(renderItem)}
                        </div>
                    )}
                </nav>
            </aside>
        </>
    );
};

export default Sidebar;
