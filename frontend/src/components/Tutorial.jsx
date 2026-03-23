import { useState, useEffect } from 'react';
import { useColors, LIGHT } from '../hooks/useColors';

const STEPS = [
    {
        title: 'Welcome to Aletheia',
        body: 'Deterministic behavioral verification for COBOL-to-Python migration. No confidence scores — just VERIFIED or REQUIRES MANUAL REVIEW.',
    },
    {
        title: 'Analyze',
        body: 'Paste any COBOL program to see every variable, every risk, every arithmetic decision — instantly.',
    },
    {
        title: 'Verify',
        body: 'Upload mainframe output and migrated output. Prove they match — field by field, byte by byte.',
    },
];

const STORAGE_KEY = 'aletheia_tutorial_done';

const Tutorial = () => {
    const C = useColors() || LIGHT;
    const [step, setStep] = useState(0);
    const [visible, setVisible] = useState(false);

    useEffect(() => {
        if (!localStorage.getItem(STORAGE_KEY)) {
            setVisible(true);
        }
    }, []);

    if (!visible) return null;

    const handleNext = () => {
        if (step < STEPS.length - 1) {
            setStep(step + 1);
        } else {
            localStorage.setItem(STORAGE_KEY, 'true');
            setVisible(false);
        }
    };

    const handleSkip = () => {
        localStorage.setItem(STORAGE_KEY, 'true');
        setVisible(false);
    };

    const current = STEPS[step];

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm bg-black/20">
            <div
                className="max-w-md w-full mx-4 rounded-xl shadow-lg p-8"
                style={{ backgroundColor: C.bg }}
            >
                <h2
                    className="text-xl font-medium mb-3"
                    style={{ color: C.text }}
                >
                    {current.title}
                </h2>
                <p className="text-sm leading-relaxed" style={{ color: C.muted }}>
                    {current.body}
                </p>

                {/* Step dots */}
                <div className="flex gap-1.5 mt-6 mb-4 justify-center">
                    {STEPS.map((_, i) => (
                        <div
                            key={i}
                            className="w-2 h-2 rounded-full transition-all duration-150"
                            style={{
                                backgroundColor: i === step ? C.gold : C.border,
                            }}
                        />
                    ))}
                </div>

                {/* Actions */}
                <div className="flex items-center justify-between mt-4">
                    <button
                        onClick={handleSkip}
                        className="text-xs transition-colors duration-150"
                        style={{ color: C.muted }}
                    >
                        Skip
                    </button>
                    <button
                        onClick={handleNext}
                        className="px-5 py-2 rounded-lg text-sm font-medium text-white transition-opacity duration-150 hover:opacity-90"
                        style={{ backgroundColor: C.gold }}
                    >
                        {step < STEPS.length - 1 ? 'Next' : 'Get Started'}
                    </button>
                </div>
            </div>
        </div>
    );
};

export default Tutorial;
