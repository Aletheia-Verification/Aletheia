import { useState } from 'react';
import { Settings } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import CodeInput from '../components/CodeInput';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';

const OPTION_LABELS = {
    TRUNC: 'Truncation Mode',
    ARITH: 'Arithmetic Precision',
    NUMPROC: 'Numeric Processing',
    'DECIMAL-POINT': 'Decimal Point',
};

const OptionRow = ({ option, detected, defaultVal, constructs, C }) => {
    const isDetected = detected !== null && detected !== undefined;
    return (
        <tr className="border-t" style={{ borderColor: C.border }}>
            <td className="px-4 py-3">
                <div className="text-[11px] font-mono font-semibold" style={{ color: C.text }}>{option}</div>
                <div className="text-[9px]" style={{ color: C.faint }}>{OPTION_LABELS[option]}</div>
            </td>
            <td className="px-4 py-3">
                {isDetected ? (
                    <span
                        className="inline-block px-3 py-1 text-[10px] tracking-[0.1em] uppercase font-semibold"
                        style={{ backgroundColor: '#F0FDF4', color: '#16A34A', border: '1px solid #16A34A' }}
                    >
                        {detected}
                    </span>
                ) : (
                    <span
                        className="inline-block px-3 py-1 text-[10px] tracking-[0.1em] uppercase font-semibold"
                        style={{ backgroundColor: '#FFFBEB', color: '#D97706', border: '1px solid #D97706' }}
                    >
                        DEFAULT: {defaultVal}
                    </span>
                )}
            </td>
            <td className="px-4 py-3 text-[10px]" style={{ color: C.faint }}>
                {constructs?.length > 0 ? constructs.join(', ') : '—'}
            </td>
        </tr>
    );
};

const CompilerMatrixPage = () => {
    const C = useColors() || LIGHT;
    const [cobolCode, setCobolCode] = useState('');
    const [fileName, setFileName] = useState('');
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const analyze = async () => {
        if (!cobolCode.trim()) return;
        setLoading(true);
        setError(null);
        setResult(null);

        try {
            const res = await authApi.post('/engine/compiler-matrix', {
                cobol_code: cobolCode,
                filename: fileName || 'input.cbl',
            });
            if (!res.ok) {
                const err = await res.json();
                throw new Error(err.detail || 'Analysis failed');
            }
            const data = await res.json();
            setResult(data.matrix);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    };

    const OPTIONS = ['TRUNC', 'ARITH', 'NUMPROC', 'DECIMAL-POINT'];

    return (
        <div>
            <PageHeader
                icon={Settings}
                title="Compiler Option Matrix"
                subtitle="Analyze which IBM z/OS compiler options your program requires"
            />

            {!result && !loading && (
                <div>
                    <CodeInput
                        value={cobolCode}
                        onChange={setCobolCode}
                        onFileSelect={setFileName}
                        fileName={fileName}
                    />
                    <button
                        onClick={analyze}
                        disabled={!cobolCode.trim()}
                        className="mt-4 px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90 disabled:opacity-40"
                        style={{ backgroundColor: C.navy }}
                    >
                        Analyze Compiler Options
                    </button>
                </div>
            )}

            {loading && <LoadingState label="Analyzing compiler options..." />}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {result && (
                <div>
                    {/* Matrix Table */}
                    <div className="border mb-6" style={{ borderColor: C.border }}>
                        <table className="w-full text-left">
                            <thead>
                                <tr style={{ backgroundColor: '#F8F9FA' }}>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Option</th>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Status</th>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Constructs</th>
                                </tr>
                            </thead>
                            <tbody>
                                {OPTIONS.map((opt) => (
                                    <OptionRow
                                        key={opt}
                                        option={opt}
                                        detected={result.detected_options?.[opt]}
                                        defaultVal={result.defaults_applied?.[opt]}
                                        constructs={result.constructs_requiring_options?.[opt]}
                                        C={C}
                                    />
                                ))}
                            </tbody>
                        </table>
                    </div>

                    {/* Warnings */}
                    {result.warnings?.length > 0 && (
                        <div className="mb-6 space-y-2">
                            {result.warnings.map((w, i) => (
                                <div
                                    key={i}
                                    className="px-4 py-3 text-[11px] border-l-[3px]"
                                    style={{ borderLeftColor: '#D97706', backgroundColor: '#FFFBEB', color: '#D97706' }}
                                >
                                    {w}
                                </div>
                            ))}
                        </div>
                    )}

                    {/* Recommendation */}
                    {result.recommendation && (
                        <div
                            className="px-4 py-4 text-[11px] leading-relaxed border-l-[3px] mb-6"
                            style={{ borderLeftColor: C.navy, backgroundColor: '#F8F9FA', color: C.text }}
                        >
                            <div className="text-[9px] tracking-[0.12em] uppercase font-semibold mb-1" style={{ color: C.faint }}>
                                Recommendation
                            </div>
                            {result.recommendation}
                        </div>
                    )}

                    <button
                        onClick={() => { setResult(null); setCobolCode(''); setFileName(''); }}
                        className="px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.faint }}
                    >
                        New Analysis
                    </button>
                </div>
            )}
        </div>
    );
};

export default CompilerMatrixPage;
