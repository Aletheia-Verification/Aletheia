import { useState, useRef } from 'react';
import { Grid3X3, Upload, ChevronDown, ChevronUp } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import StatusBadge from '../components/StatusBadge';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';

const COLOR_MAP = {
    green: { bg: '#F0FDF4', border: '#16A34A', text: '#16A34A' },
    yellow: { bg: '#FFFBEB', border: '#D97706', text: '#D97706' },
    red: { bg: '#FEF2F2', border: '#DC2626', text: '#DC2626' },
};

const SummaryCard = ({ label, value, color, C: _C }) => {
    const C = _C || LIGHT;
    return (
        <div
            className="p-4 text-center border"
            style={{ borderColor: color || C.border, borderTopWidth: 2, borderTopColor: color || C.navy }}
        >
            <div className="text-2xl font-mono font-bold" style={{ color: color || C.navy }}>{value}</div>
            <div className="text-[10px] tracking-[0.1em] uppercase mt-1" style={{ color: C.faint }}>{label}</div>
        </div>
    );
};

const ProgramCell = ({ program, expanded, onToggle, C }) => {
    if (!C) C = LIGHT;
    const colors = COLOR_MAP[program.status] || COLOR_MAP.green;
    return (
        <div
            className="border-l-[3px] p-4 cursor-pointer transition-all duration-150 hover:shadow-sm"
            style={{ backgroundColor: colors.bg, borderLeftColor: colors.border }}
            onClick={onToggle}
        >
            <div className="flex items-start justify-between">
                <div>
                    <div className="text-[11px] font-mono font-semibold truncate" style={{ color: C.text }}>
                        {program.name}
                    </div>
                    <div className="text-[10px] mt-1" style={{ color: C.faint }}>
                        {program.lines} lines &middot; complexity {program.complexity_score}/100
                    </div>
                </div>
                <StatusBadge status={program.status} label={program.predicted_outcome} />
            </div>

            {expanded && (
                <div className="mt-4 pt-3 border-t" style={{ borderColor: `${colors.border}40` }}>
                    {/* Constructs */}
                    {program.constructs?.length > 0 && (
                        <div className="mb-3">
                            <div className="text-[9px] tracking-[0.1em] uppercase mb-1" style={{ color: C.faint }}>Constructs</div>
                            <div className="flex flex-wrap gap-1">
                                {program.constructs.map((c, i) => (
                                    <span
                                        key={i}
                                        className="px-2 py-0.5 text-[9px] font-mono border"
                                        style={{ borderColor: C.border, color: C.text }}
                                    >
                                        {c}
                                    </span>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Risk Factors */}
                    {program.risk_factors?.length > 0 && (
                        <div className="mb-3">
                            <div className="text-[9px] tracking-[0.1em] uppercase mb-1" style={{ color: '#DC2626' }}>Risk Factors</div>
                            {program.risk_factors.map((r, i) => (
                                <div key={i} className="text-[10px] font-mono" style={{ color: '#DC2626' }}>&bull; {r}</div>
                            ))}
                        </div>
                    )}

                    {/* Complexity Bar */}
                    <div className="mt-2">
                        <div className="text-[9px] tracking-[0.1em] uppercase mb-1" style={{ color: C.faint }}>Complexity</div>
                        <div className="w-full h-2 bg-[#E5E7EB]">
                            <div
                                className="h-full transition-all duration-300"
                                style={{
                                    width: `${Math.min(program.complexity_score, 100)}%`,
                                    backgroundColor: program.complexity_score > 70 ? '#DC2626' : program.complexity_score > 40 ? '#D97706' : '#16A34A',
                                }}
                            />
                        </div>
                    </div>

                    {program.compiler_matrix_warnings > 0 && (
                        <div className="mt-2 text-[10px]" style={{ color: '#D97706' }}>
                            {program.compiler_matrix_warnings} compiler matrix warning{program.compiler_matrix_warnings !== 1 ? 's' : ''}
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

const PortfolioPage = () => {
    const C = useColors() || LIGHT;
    const fileRef = useRef(null);
    const [files, setFiles] = useState([]);
    const [heatmap, setHeatmap] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [expandedIdx, setExpandedIdx] = useState(null);
    const [progress, setProgress] = useState({ current: 0, total: 0 });

    const CHUNK_SIZE = 50;

    const handleFiles = (fileList) => {
        const newFiles = Array.from(fileList).filter(f =>
            f.name.endsWith('.cbl') || f.name.endsWith('.cob') || f.name.endsWith('.txt')
        );
        setFiles(prev => [...prev, ...newFiles]);
    };

    const handleDrop = (e) => {
        e.preventDefault();
        handleFiles(e.dataTransfer.files);
    };

    const removeFile = (idx) => {
        setFiles(prev => prev.filter((_, i) => i !== idx));
    };

    const analyzePortfolio = async () => {
        if (files.length === 0) return;
        setLoading(true);
        setError(null);
        setHeatmap(null);

        try {
            // Read all file contents
            const programs = await Promise.all(
                files.map(async (f) => {
                    const text = await f.text();
                    return { cobol_code: text, filename: f.name };
                })
            );

            setProgress({ current: 0, total: programs.length });

            // Split into chunks of CHUNK_SIZE
            const chunks = [];
            for (let i = 0; i < programs.length; i += CHUNK_SIZE) {
                chunks.push(programs.slice(i, i + CHUNK_SIZE));
            }

            // Process chunks sequentially, aggregate results
            const allPrograms = [];
            const errors = [];

            for (let ci = 0; ci < chunks.length; ci++) {
                try {
                    const res = await authApi.post('/engine/risk-heatmap', { programs: chunks[ci] });
                    if (!res.ok) {
                        const err = await res.json();
                        errors.push(`Batch ${ci + 1}: ${err.detail || 'Analysis failed'}`);
                    } else {
                        const data = await res.json();
                        if (data.heatmap?.programs) {
                            allPrograms.push(...data.heatmap.programs);
                        }
                    }
                } catch (e) {
                    errors.push(`Batch ${ci + 1}: ${e.message}`);
                }

                const processed = Math.min((ci + 1) * CHUNK_SIZE, programs.length);
                setProgress({ current: processed, total: programs.length });
            }

            if (allPrograms.length === 0) {
                throw new Error(errors.join('; ') || 'All batches failed');
            }

            // Recompute summary from merged results
            const verified = allPrograms.filter(p => p.predicted_outcome === 'VERIFIED').length;
            const summary = {
                total: allPrograms.length,
                green: allPrograms.filter(p => p.status === 'green').length,
                yellow: allPrograms.filter(p => p.status === 'yellow').length,
                red: allPrograms.filter(p => p.status === 'red').length,
                predicted_pvr: `${Math.round((verified / allPrograms.length) * 100)}%`,
            };
            setHeatmap({ programs: allPrograms, summary });

            if (errors.length > 0) {
                setError(`Partial results. Failures: ${errors.join('; ')}`);
            }
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
            setProgress({ current: 0, total: 0 });
        }
    };

    return (
        <div>
            <PageHeader
                icon={Grid3X3}
                title="Portfolio Risk Heatmap"
                subtitle="Upload multiple COBOL programs for portfolio-level risk assessment"
            />

            {/* Upload Zone */}
            {!heatmap && !loading && (
                <div className="mb-6">
                    <div
                        onDragOver={(e) => e.preventDefault()}
                        onDrop={handleDrop}
                        className="border-2 border-dashed p-8 text-center cursor-pointer transition-all duration-150 hover:border-[#1B2A4A]/30"
                        style={{ borderColor: C.border }}
                        onClick={() => fileRef.current?.click()}
                    >
                        <Upload size={24} strokeWidth={1.5} style={{ color: C.faint }} className="mx-auto mb-3" />
                        <p className="text-[11px] tracking-[0.12em] uppercase" style={{ color: C.faint }}>
                            Drop .cbl files here or click to browse
                        </p>
                        <input
                            ref={fileRef}
                            type="file"
                            accept=".cbl,.cob,.txt"
                            multiple
                            className="hidden"
                            onChange={(e) => handleFiles(e.target.files)}
                        />
                    </div>

                    {files.length > 0 && (
                        <div className="mt-4">
                            <div className="text-[10px] tracking-[0.1em] uppercase mb-2" style={{ color: C.faint }}>
                                {files.length} file{files.length !== 1 ? 's' : ''} selected
                            </div>
                            <div className="flex flex-wrap gap-2 mb-4">
                                {files.map((f, i) => (
                                    <span
                                        key={i}
                                        className="inline-flex items-center gap-1 px-3 py-1 text-[10px] font-mono border"
                                        style={{ borderColor: C.border, color: C.text }}
                                    >
                                        {f.name}
                                        <button
                                            onClick={(e) => { e.stopPropagation(); removeFile(i); }}
                                            className="ml-1 hover:text-red-500"
                                        >
                                            &times;
                                        </button>
                                    </span>
                                ))}
                            </div>
                            <button
                                onClick={analyzePortfolio}
                                className="px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90"
                                style={{ backgroundColor: C.navy }}
                            >
                                Analyze Portfolio
                            </button>
                        </div>
                    )}
                </div>
            )}

            {loading && (
                <div className="mb-6 p-6 border" style={{ borderColor: C.border }}>
                    <div className="flex items-center justify-between mb-2">
                        <span className="text-[10px] tracking-[0.12em] uppercase font-semibold" style={{ color: C.faint }}>
                            Analyzing {progress.current}/{progress.total} programs
                        </span>
                        <span className="text-[11px] font-mono font-bold" style={{ color: C.navy }}>
                            {progress.total > 0 ? Math.round((progress.current / progress.total) * 100) : 0}%
                        </span>
                    </div>
                    <div className="w-full h-2" style={{ backgroundColor: C.border }}>
                        <div
                            className="h-full transition-all duration-500"
                            style={{
                                width: `${progress.total > 0 ? (progress.current / progress.total) * 100 : 0}%`,
                                backgroundColor: C.navy,
                            }}
                        />
                    </div>
                    {progress.total > progress.current && (
                        <div className="text-[10px] font-mono mt-2" style={{ color: C.faint }}>
                            ~{Math.ceil((progress.total - progress.current) * 3)}s remaining
                        </div>
                    )}
                </div>
            )}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {/* Results */}
            {heatmap && (
                <div>
                    {/* Summary */}
                    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 mb-6">
                        <SummaryCard label="Total" value={heatmap.summary.total} C={C} />
                        <SummaryCard label="Green" value={heatmap.summary.green} color="#16A34A" C={C} />
                        <SummaryCard label="Yellow" value={heatmap.summary.yellow} color="#D97706" C={C} />
                        <SummaryCard label="Red" value={heatmap.summary.red} color="#DC2626" C={C} />
                        <SummaryCard label="Predicted PVR" value={heatmap.summary.predicted_pvr} color={C.gold} C={C} />
                    </div>

                    {/* Heatmap Grid */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
                        {heatmap.programs.map((prog, i) => (
                            <ProgramCell
                                key={i}
                                program={prog}
                                expanded={expandedIdx === i}
                                onToggle={() => setExpandedIdx(expandedIdx === i ? null : i)}
                                C={C}
                            />
                        ))}
                    </div>

                    {/* Reset */}
                    <button
                        onClick={() => { setHeatmap(null); setFiles([]); setExpandedIdx(null); }}
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

export default PortfolioPage;
