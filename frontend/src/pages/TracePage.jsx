import { useState } from 'react';
import { Activity, ArrowRight, RotateCcw } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import CodeInput from '../components/CodeInput';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';
import StatusBadge from '../components/StatusBadge';

const StatBox = ({ label, value, color, C: _C }) => {
    const C = _C || LIGHT;
    return (
        <div className="p-4 border" style={{ borderColor: C.border }}>
            <div className="text-[9px] uppercase tracking-[0.15em] font-semibold mb-1" style={{ color: C.faint }}>
                {label}
            </div>
            <div className="text-lg font-mono font-semibold" style={{ color: color || C.text }}>
                {value}
            </div>
        </div>
    );
};

const TraceEvent = ({ event, index, divergenceIndex, C }) => {
    const isDivergence = divergenceIndex >= 0 && index === divergenceIndex;
    const isAfterDivergence = divergenceIndex >= 0 && index > divergenceIndex;
    const isMatch = divergenceIndex < 0 || index < divergenceIndex;

    let bgColor = C.bg;
    let opacity = 1;

    if (isDivergence) {
        bgColor = C.redBg;
    } else if (isMatch) {
        bgColor = index % 2 === 0 ? C.bg : C.bgAlt;
    }

    if (isAfterDivergence) {
        opacity = 0.4;
    }

    return (
        <div
            className="flex items-start gap-4 px-5 py-3 border-l-3"
            style={{
                borderLeftWidth: '3px',
                borderLeftColor: isDivergence ? C.red : isMatch ? C.green : C.border,
                backgroundColor: bgColor,
                opacity,
            }}
        >
            <span className="text-[10px] font-mono w-8 shrink-0 pt-0.5" style={{ color: C.faint }}>
                #{index}
            </span>
            <span className="text-[10px] font-mono w-12 shrink-0 pt-0.5" style={{ color: C.muted }}>
                L{event.line || '—'}
            </span>
            <span
                className="text-[11px] font-mono font-semibold w-24 shrink-0 uppercase"
                style={{ color: isDivergence ? C.red : C.navy }}
            >
                {event.verb || event.type || '—'}
            </span>
            <span className="text-[11px] font-mono w-32 shrink-0" style={{ color: C.body }}>
                {event.variable || event.field || '—'}
            </span>
            <div className="flex items-center gap-2 text-[11px] font-mono flex-1 min-w-0">
                <span style={{ color: C.muted }}>{event.before ?? event.ref_value ?? '—'}</span>
                <ArrowRight size={10} style={{ color: C.faint }} className="shrink-0" />
                <span style={{ color: isDivergence ? C.red : C.text, fontWeight: isDivergence ? 700 : 400 }}>
                    {event.after ?? event.mig_value ?? '—'}
                </span>
            </div>
            {isAfterDivergence && (
                <span className="text-[9px] italic tracking-wider uppercase shrink-0" style={{ color: C.faint }}>
                    unreliable
                </span>
            )}
            {isDivergence && event.diagnosis && (
                <div className="text-[10px] mt-1 pl-8" style={{ color: C.red }}>
                    {event.diagnosis}
                </div>
            )}
        </div>
    );
};

export default function TracePage() {
    const C = useColors() || LIGHT;
    const [refTrace, setRefTrace] = useState('');
    const [migTrace, setMigTrace] = useState('');
    const [refFileName, setRefFileName] = useState('');
    const [migFileName, setMigFileName] = useState('');
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const compare = async () => {
        if (!refTrace.trim() || !migTrace.trim()) return;
        setLoading(true);
        setError(null);
        setResult(null);

        try {
            let refParsed, migParsed;
            try {
                refParsed = JSON.parse(refTrace);
            } catch {
                throw new Error('Invalid JSON in Reference Trace');
            }
            try {
                migParsed = JSON.parse(migTrace);
            } catch {
                throw new Error('Invalid JSON in Migration Trace');
            }

            const res = await authApi.post('/engine/trace-compare', {
                reference_trace: refParsed,
                migration_trace: migParsed,
            });
            if (!res.ok) {
                const err = await res.json();
                throw new Error(err.detail || 'Trace comparison failed');
            }
            const data = await res.json();
            setResult(data);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    };

    const reset = () => {
        setResult(null);
        setRefTrace('');
        setMigTrace('');
        setRefFileName('');
        setMigFileName('');
        setError(null);
    };

    const events = result?.events || result?.trace_events || [];
    const divergenceIndex = result?.divergence_index ?? -1;
    const matchCount = divergenceIndex < 0 ? events.length : divergenceIndex;
    const divergenceEvent = divergenceIndex >= 0 ? events[divergenceIndex] : null;

    return (
        <div className="p-8 max-w-6xl mx-auto">
            <PageHeader
                icon={Activity}
                title="Trace Compare"
                subtitle="Compare execution traces between reference and migration"
            />

            {/* ── Phase 1: Input ── */}
            {!result && !loading && !error && (
                <div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
                        <div>
                            <div className="text-[10px] font-semibold uppercase tracking-[0.15em] mb-3" style={{ color: C.navy }}>
                                Reference Trace
                            </div>
                            <CodeInput
                                value={refTrace}
                                onChange={setRefTrace}
                                onFileSelect={setRefFileName}
                                fileName={refFileName}
                                placeholder="Paste reference trace JSON here..."
                                language="JSON"
                            />
                        </div>
                        <div>
                            <div className="text-[10px] font-semibold uppercase tracking-[0.15em] mb-3" style={{ color: C.navy }}>
                                Migration Trace
                            </div>
                            <CodeInput
                                value={migTrace}
                                onChange={setMigTrace}
                                onFileSelect={setMigFileName}
                                fileName={migFileName}
                                placeholder="Paste migration trace JSON here..."
                                language="JSON"
                            />
                        </div>
                    </div>
                    <button
                        onClick={compare}
                        disabled={!refTrace.trim() || !migTrace.trim()}
                        className="px-6 py-2.5 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 disabled:opacity-30"
                        style={{ backgroundColor: C.navy }}
                    >
                        Compare Traces
                    </button>
                </div>
            )}

            {/* ── Phase 2: Loading ── */}
            {loading && <LoadingState label="Comparing traces..." />}

            {/* ── Error ── */}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {/* ── Phase 3: Results ── */}
            {result && (
                <div>
                    {/* Divergence banner */}
                    {divergenceIndex >= 0 && divergenceEvent ? (
                        <div className="mb-6 p-5 border" style={{ borderColor: C.redBorder, backgroundColor: C.redBg }}>
                            <div className="flex items-center gap-3 mb-2">
                                <StatusBadge status="red" label="DIVERGENCE DETECTED" />
                            </div>
                            <p className="text-[12px] font-mono leading-relaxed" style={{ color: C.red }}>
                                Divergence at event #{divergenceIndex}:
                                {' '}{divergenceEvent.verb || divergenceEvent.type} on {divergenceEvent.variable || divergenceEvent.field}.
                                {' '}Reference: {divergenceEvent.before ?? divergenceEvent.ref_value ?? '—'}
                                {' '}/ Migration: {divergenceEvent.after ?? divergenceEvent.mig_value ?? '—'}.
                            </p>
                            {(divergenceEvent.diagnosis || result.diagnosis) && (
                                <p className="text-[11px] mt-2" style={{ color: C.body }}>
                                    Diagnosis: {divergenceEvent.diagnosis || result.diagnosis}
                                </p>
                            )}
                        </div>
                    ) : (
                        <div className="mb-6 p-5 border" style={{ borderColor: C.greenBorder, backgroundColor: C.greenBg }}>
                            <div className="flex items-center gap-3">
                                <StatusBadge status="green" label="TRACES MATCH" />
                                <span className="text-[11px] tracking-[0.1em]" style={{ color: C.green }}>
                                    All {events.length} events verified identical
                                </span>
                            </div>
                        </div>
                    )}

                    {/* Stats bar */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                        <StatBox label="Total Events" value={events.length} C={C} />
                        <StatBox label="Matching" value={matchCount} color={C.green} C={C} />
                        <StatBox
                            label="Divergence Index"
                            value={divergenceIndex >= 0 ? `#${divergenceIndex}` : '—'}
                            color={divergenceIndex >= 0 ? C.red : C.faint}
                            C={C}
                        />
                        <StatBox
                            label="Status"
                            value={divergenceIndex >= 0 ? 'DIVERGED' : 'MATCH'}
                            color={divergenceIndex >= 0 ? C.red : C.green}
                            C={C}
                        />
                    </div>

                    {/* Timeline */}
                    <div className="mb-6">
                        <div className="text-[10px] font-semibold uppercase tracking-[0.15em] mb-3" style={{ color: C.navy }}>
                            Event Timeline
                        </div>
                        <div className="border" style={{ borderColor: C.border }}>
                            {/* Header */}
                            <div className="flex items-center gap-4 px-5 py-2 border-b" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                                <span className="text-[9px] uppercase tracking-wider font-semibold w-8" style={{ color: C.faint }}>#</span>
                                <span className="text-[9px] uppercase tracking-wider font-semibold w-12" style={{ color: C.faint }}>Line</span>
                                <span className="text-[9px] uppercase tracking-wider font-semibold w-24" style={{ color: C.faint }}>Verb</span>
                                <span className="text-[9px] uppercase tracking-wider font-semibold w-32" style={{ color: C.faint }}>Variable</span>
                                <span className="text-[9px] uppercase tracking-wider font-semibold flex-1" style={{ color: C.faint }}>Value Transition</span>
                            </div>
                            {/* Events */}
                            {events.length > 0 ? (
                                events.map((event, i) => (
                                    <TraceEvent
                                        key={i}
                                        event={event}
                                        index={i}
                                        divergenceIndex={divergenceIndex}
                                        C={C}
                                    />
                                ))
                            ) : (
                                <div className="p-8 text-center text-[11px] tracking-wider" style={{ color: C.faint }}>
                                    No trace events returned
                                </div>
                            )}
                        </div>
                    </div>

                    {/* New Comparison button */}
                    <button
                        onClick={reset}
                        className="flex items-center gap-2 px-5 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                        style={{ borderColor: C.navy, color: C.navy }}
                    >
                        <RotateCcw size={12} strokeWidth={1.5} />
                        New Comparison
                    </button>
                </div>
            )}
        </div>
    );
}
