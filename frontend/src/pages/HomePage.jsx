import { Link } from 'react-router-dom';
import { Cpu, GitCompareArrows } from 'lucide-react';
import Logo from '../components/Logo';
import Tutorial from '../components/Tutorial';
import { useColors, LIGHT } from '../hooks/useColors';

const HomePage = () => {
    const C = useColors() || LIGHT;

    return (
        <div
            className="min-h-screen flex items-center justify-center p-6"
            style={{ backgroundColor: C.bgAlt }}
        >
            <div className="max-w-4xl w-full">
                {/* Logo + welcome */}
                <div className="text-center mb-12">
                    <div className="hidden md:flex justify-center">
                        <Logo size={20} theme="navy" />
                    </div>
                    <h1
                        className="text-2xl font-medium mt-4"
                        style={{ color: C.text }}
                    >
                        Aletheia
                    </h1>
                    <p className="text-sm mt-1" style={{ color: C.muted }}>
                        Behavioral verification for COBOL migrations
                    </p>
                </div>

                {/* Two cards */}
                <div className="grid md:grid-cols-2 gap-6">
                    {/* Card 1: Analyze */}
                    <Link
                        to="/analyze"
                        className="rounded-xl shadow-sm p-8 hover:shadow-md transition-shadow duration-150 block"
                        style={{
                            backgroundColor: C.bg,
                            border: `1px solid ${C.border}`,
                        }}
                    >
                        <Cpu
                            size={32}
                            strokeWidth={1.5}
                            style={{ color: C.navy }}
                            className="mb-4"
                        />
                        <h2
                            className="text-lg font-medium"
                            style={{ color: C.text }}
                        >
                            Analyze COBOL
                        </h2>
                        <p className="text-sm mt-2" style={{ color: C.muted }}>
                            Understand your program. See every risk.
                        </p>
                    </Link>

                    {/* Card 2: Verify */}
                    <Link
                        to="/verify"
                        className="rounded-xl shadow-sm p-8 hover:shadow-md transition-shadow duration-150 block"
                        style={{
                            backgroundColor: C.bg,
                            border: `1px solid ${C.border}`,
                        }}
                    >
                        <GitCompareArrows
                            size={32}
                            strokeWidth={1.5}
                            style={{ color: C.navy }}
                            className="mb-4"
                        />
                        <h2
                            className="text-lg font-medium"
                            style={{ color: C.text }}
                        >
                            Verify Migration
                        </h2>
                        <p className="text-sm mt-2" style={{ color: C.muted }}>
                            Prove your migration matches the mainframe.
                        </p>
                    </Link>
                </div>
            </div>

            {/* Tutorial overlay — first visit only */}
            <Tutorial />
        </div>
    );
};

export default HomePage;
