import { useState } from 'react';
import { Workflow, ChevronDown, ChevronUp } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';

const StepCard = ({ step, index, expanded, onToggle, C }) => (
    <div className="border mb-2" style={{ borderColor: C.border }}>
        <button
            onClick={onToggle}
            className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-[#F8F9FA] transition-all duration-150"
        >
            <div className="flex items-center gap-3">
                <span
                    className="w-6 h-6 flex items-center justify-center text-[10px] font-mono font-bold text-white"
                    style={{ backgroundColor: C.navy }}
                >
                    {index + 1}
                </span>
                <div>
                    <div className="text-[11px] font-mono font-semibold" style={{ color: C.text }}>
                        {step.name || `STEP${index + 1}`}
                    </div>
                    <div className="text-[10px]" style={{ color: C.faint }}>
                        {step.program ? `PGM=${step.program}` : ''}
                        {step.proc ? `PROC=${step.proc}` : ''}
                    </div>
                </div>
            </div>
            {expanded ? (
                <ChevronUp size={14} style={{ color: C.faint }} />
            ) : (
                <ChevronDown size={14} style={{ color: C.faint }} />
            )}
        </button>

        {expanded && (
            <div className="px-4 pb-4 border-t" style={{ borderColor: C.border }}>
                {/* COND */}
                {step.cond && (
                    <div className="mt-3">
                        <div className="text-[9px] tracking-[0.1em] uppercase mb-1" style={{ color: C.faint }}>Condition</div>
                        <div className="text-[10px] font-mono" style={{ color: C.text }}>{step.cond}</div>
                    </div>
                )}

                {/* DD Statements */}
                {step.dd_statements?.length > 0 && (
                    <div className="mt-3">
                        <div className="text-[9px] tracking-[0.1em] uppercase mb-1" style={{ color: C.faint }}>
                            DD Statements ({step.dd_statements.length})
                        </div>
                        <div className="space-y-1">
                            {step.dd_statements.map((dd, i) => (
                                <div key={i} className="flex items-start gap-2 text-[10px] font-mono" style={{ color: C.text }}>
                                    <span className="font-semibold min-w-[80px]">{dd.name}</span>
                                    <span style={{ color: C.faint }}>
                                        {dd.dsn || ''}
                                        {dd.disp ? ` (${dd.disp})` : ''}
                                        {dd.sysout ? ` SYSOUT=${dd.sysout}` : ''}
                                        {dd.is_instream ? ' [INSTREAM]' : ''}
                                    </span>
                                </div>
                            ))}
                        </div>
                    </div>
                )}
            </div>
        )}
    </div>
);

const JCLPage = () => {
    const C = useColors() || LIGHT;
    const [jclText, setJclText] = useState('');
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [expandedSteps, setExpandedSteps] = useState(new Set());

    const parse = async () => {
        if (!jclText.trim()) return;
        setLoading(true);
        setError(null);
        setResult(null);

        try {
            const res = await authApi.post('/engine/parse-jcl', { jcl_text: jclText });
            if (!res.ok) {
                const err = await res.json();
                throw new Error(err.detail || 'Parse failed');
            }
            setResult(await res.json());
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    };

    const toggleStep = (idx) => {
        setExpandedSteps(prev => {
            const next = new Set(prev);
            if (next.has(idx)) next.delete(idx);
            else next.add(idx);
            return next;
        });
    };

    const expandAll = () => {
        if (!result?.steps) return;
        setExpandedSteps(new Set(result.steps.map((_, i) => i)));
    };

    return (
        <div>
            <PageHeader
                icon={Workflow}
                title="JCL Parser"
                subtitle="Parse IBM JCL job control language into a structured step diagram"
            />

            {!result && !loading && (
                <div>
                    <textarea
                        value={jclText}
                        onChange={(e) => setJclText(e.target.value)}
                        placeholder="Paste JCL here..."
                        className="w-full h-72 p-4 font-mono text-[12px] leading-relaxed border resize-y focus:outline-none"
                        style={{ borderColor: C.border, color: C.text }}
                        spellCheck={false}
                    />
                    <button
                        onClick={parse}
                        disabled={!jclText.trim()}
                        className="mt-4 px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90 disabled:opacity-40"
                        style={{ backgroundColor: C.navy }}
                    >
                        Parse JCL
                    </button>
                </div>
            )}

            {loading && <LoadingState label="Parsing JCL..." />}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {result && (
                <div>
                    {/* Job Name */}
                    <div
                        className="px-4 py-3 mb-4 border-l-[3px]"
                        style={{ borderLeftColor: C.navy, backgroundColor: '#F8F9FA' }}
                    >
                        <div className="text-[9px] tracking-[0.1em] uppercase" style={{ color: C.faint }}>Job Name</div>
                        <div className="text-base font-mono font-bold" style={{ color: C.text }}>
                            {result.job_name || 'UNKNOWN'}
                        </div>
                    </div>

                    {/* Controls */}
                    <div className="flex items-center gap-3 mb-4">
                        <span className="text-[10px] tracking-[0.1em] uppercase" style={{ color: C.faint }}>
                            {result.steps?.length || 0} step{(result.steps?.length || 0) !== 1 ? 's' : ''}
                        </span>
                        <button
                            onClick={expandAll}
                            className="text-[10px] tracking-[0.1em] uppercase underline hover:opacity-70"
                            style={{ color: C.navy }}
                        >
                            Expand All
                        </button>
                        <button
                            onClick={() => setExpandedSteps(new Set())}
                            className="text-[10px] tracking-[0.1em] uppercase underline hover:opacity-70"
                            style={{ color: C.faint }}
                        >
                            Collapse All
                        </button>
                    </div>

                    {/* Steps */}
                    {result.steps?.map((step, i) => (
                        <StepCard
                            key={i}
                            step={step}
                            index={i}
                            expanded={expandedSteps.has(i)}
                            onToggle={() => toggleStep(i)}
                            C={C}
                        />
                    ))}

                    {/* Dataset Dependencies */}
                    {result.dependencies?.length > 0 && (
                        <div className="mt-6 mb-6">
                            <h3 className="text-[11px] tracking-[0.15em] uppercase font-semibold mb-3" style={{ color: C.text }}>
                                Dataset Flow
                            </h3>
                            <div className="border" style={{ borderColor: C.border }}>
                                {result.dependencies.map(([src, dst], i) => (
                                    <div
                                        key={i}
                                        className="flex items-center gap-2 px-4 py-2 text-[10px] font-mono border-t first:border-t-0"
                                        style={{ borderColor: C.border }}
                                    >
                                        <span style={{ color: C.navy }} className="font-semibold">{src}</span>
                                        <span style={{ color: C.faint }}>&rarr;</span>
                                        <span style={{ color: C.green }} className="font-semibold">{dst}</span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Summary */}
                    {result.summary && (
                        <div
                            className="px-4 py-3 text-[11px] leading-relaxed border-l-[3px] mb-6"
                            style={{ borderLeftColor: C.navy, backgroundColor: '#F8F9FA', color: C.text }}
                        >
                            <div className="text-[9px] tracking-[0.1em] uppercase font-semibold mb-1" style={{ color: C.faint }}>
                                Summary
                            </div>
                            {result.summary}
                        </div>
                    )}

                    <button
                        onClick={() => { setResult(null); setJclText(''); setExpandedSteps(new Set()); }}
                        className="px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.faint }}
                    >
                        New Parse
                    </button>
                </div>
            )}
        </div>
    );
};

export default JCLPage;
