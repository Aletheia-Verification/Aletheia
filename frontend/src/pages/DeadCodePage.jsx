import { useState } from 'react';
import { Skull, AlertTriangle } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import CodeInput from '../components/CodeInput';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';

const StatBox = ({ label, value, color, C: _C }) => {
    const C = _C || LIGHT;
    return (
    <div className="border p-4 text-center" style={{ borderColor: C.border }}>
        <div className="text-xl font-mono font-bold" style={{ color: color || C.navy }}>{value}</div>
        <div className="text-[9px] tracking-[0.1em] uppercase mt-1" style={{ color: C.faint }}>{label}</div>
    </div>
    );
};

const DeadCodePage = () => {
    const C = useColors() || LIGHT;
    const [cobolCode, setCobolCode] = useState('');
    const [fileName, setFileName] = useState('');
    const [deadCode, setDeadCode] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const analyze = async () => {
        if (!cobolCode.trim()) return;
        setLoading(true);
        setError(null);
        setDeadCode(null);

        try {
            const res = await authApi.post('/engine/analyze', {
                cobol_code: cobolCode,
                filename: fileName || 'input.cbl',
            });
            if (!res.ok) {
                const err = await res.json();
                throw new Error(err.detail || 'Analysis failed');
            }
            const data = await res.json();
            setDeadCode(data.dead_code || {
                unreachable_paragraphs: [],
                total_paragraphs: 0,
                reachable_paragraphs: 0,
                dead_percentage: 0,
                has_alter: false,
            });
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    };

    const reachablePct = deadCode
        ? (deadCode.total_paragraphs > 0
            ? ((deadCode.reachable_paragraphs / deadCode.total_paragraphs) * 100).toFixed(1)
            : 100)
        : 0;
    const deadPct = deadCode?.dead_percentage?.toFixed?.(1) || '0.0';

    return (
        <div>
            <PageHeader
                icon={Skull}
                title="Dead Code Analysis"
                subtitle="Detect unreachable paragraphs in your COBOL program"
            />

            {!deadCode && !loading && (
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
                        Analyze Dead Code
                    </button>
                </div>
            )}

            {loading && <LoadingState label="Analyzing paragraph reachability..." />}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {deadCode && (
                <div>
                    {/* ALTER Warning */}
                    {deadCode.has_alter && (
                        <div
                            className="flex items-center gap-2 px-4 py-3 mb-6 border-l-[3px]"
                            style={{ borderLeftColor: C.red, backgroundColor: '#FEF2F2', color: C.red }}
                        >
                            <AlertTriangle size={16} strokeWidth={1.5} />
                            <span className="text-[11px] font-semibold">ALTER detected — dynamic dispatch makes reachability analysis unreliable</span>
                        </div>
                    )}

                    {/* Progress Bar */}
                    <div className="mb-6">
                        <div className="flex justify-between text-[9px] tracking-[0.1em] uppercase mb-1">
                            <span style={{ color: C.green }}>Reachable {reachablePct}%</span>
                            <span style={{ color: C.red }}>Dead {deadPct}%</span>
                        </div>
                        <div className="w-full h-3 bg-[#E5E7EB] flex overflow-hidden">
                            <div
                                className="h-full transition-all duration-300"
                                style={{ width: `${reachablePct}%`, backgroundColor: C.green }}
                            />
                            <div
                                className="h-full transition-all duration-300"
                                style={{ width: `${deadPct}%`, backgroundColor: C.red }}
                            />
                        </div>
                    </div>

                    {/* Stats */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
                        <StatBox label="Total Paragraphs" value={deadCode.total_paragraphs} C={C} />
                        <StatBox label="Reachable" value={deadCode.reachable_paragraphs} color={C.green} C={C} />
                        <StatBox label="Dead" value={deadCode.unreachable_paragraphs?.length || 0} color={C.red} C={C} />
                        <StatBox label="Dead %" value={`${deadPct}%`} color={parseFloat(deadPct) > 0 ? C.amber : C.green} C={C} />
                    </div>

                    {/* Unreachable Paragraphs */}
                    {deadCode.unreachable_paragraphs?.length > 0 && (
                        <div className="mb-6">
                            <h3 className="text-[11px] tracking-[0.15em] uppercase font-semibold mb-3" style={{ color: C.text }}>
                                Unreachable Paragraphs
                            </h3>
                            <div className="border" style={{ borderColor: C.border }}>
                                {deadCode.unreachable_paragraphs.map((p, i) => (
                                    <div
                                        key={i}
                                        className="px-4 py-2 text-[11px] font-mono flex items-center gap-2 border-t first:border-t-0"
                                        style={{ borderColor: C.border, color: C.red }}
                                    >
                                        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: C.red }} />
                                        {typeof p === 'string' ? p : p.name || p.paragraph || JSON.stringify(p)}
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {deadCode.unreachable_paragraphs?.length === 0 && (
                        <div
                            className="px-4 py-4 text-[11px] border-l-[3px] mb-6"
                            style={{ borderLeftColor: C.green, backgroundColor: '#F0FDF4', color: C.green }}
                        >
                            All paragraphs are reachable. No dead code detected.
                        </div>
                    )}

                    <button
                        onClick={() => { setDeadCode(null); setCobolCode(''); setFileName(''); }}
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

export default DeadCodePage;
