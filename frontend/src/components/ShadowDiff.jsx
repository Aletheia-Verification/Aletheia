import React, { useState, useRef } from 'react';
import {
    GitCompareArrows, Upload, FileJson, FileText, Cpu,
    CheckCircle, XCircle, ChevronDown, Download, RotateCcw,
    Play, Zap, ShieldCheck, Check
} from 'lucide-react';
import { apiUrl } from '../config/api';
import { generateShadowDiffPDF } from '../utils/shadowDiffPdf';

// ── Color Constants (matches Engine.jsx) ──────────────────────────
const C = {
    navy: '#1B2A4A',
    navyLight: '#2D3F5E',
    text: '#1A1A2E',
    body: '#2D2D3D',
    muted: '#5A5A6E',
    faint: '#6B7280',
    border: '#E5E7EB',
    borderLight: '#F0F0F0',
    bg: '#FFFFFF',
    bgAlt: '#F8F9FA',
    green: '#16A34A',
    greenBg: '#F0FDF4',
    greenBorder: '#BBF7D0',
    amber: '#D97706',
    amberBg: '#FFFBEB',
    amberBorder: '#FDE68A',
    red: '#DC2626',
    redBg: '#FEF2F2',
    redBorder: '#FECACA',
    gold: '#C9A84C',
};

// ── Processing Loader ─────────────────────────────────────────────
const DiffLoader = ({ stage }) => {
    const stages = [
        { id: 'parsing', label: 'Parsing Input Records', icon: FileText },
        { id: 'executing', label: 'Executing Verification Model', icon: Cpu },
        { id: 'comparing', label: 'Comparing Outputs', icon: GitCompareArrows },
        { id: 'reporting', label: 'Generating Report', icon: ShieldCheck },
    ];
    const currentIndex = stages.findIndex(s => s.id === stage);

    return (
        <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-12 bg-white">
            <div className="relative">
                <div
                    className="w-20 h-20 border border-[#E5E7EB] border-t-[#1B2A4A] animate-spin"
                    style={{ borderRadius: '50%', animationDuration: '3s' }}
                />
                <GitCompareArrows className="absolute inset-0 m-auto w-7 h-7 animate-pulse" style={{ color: C.navy }} strokeWidth={1.5} />
            </div>
            <div className="text-center space-y-2">
                <h2 className="text-base font-medium tracking-[0.2em] uppercase" style={{ color: C.text }}>Processing</h2>
                <p className="text-xs tracking-[0.15em] uppercase" style={{ color: C.faint }}>
                    {stages[currentIndex >= 0 ? currentIndex : 0].label}
                </p>
            </div>
            <div className="flex gap-8">
                {stages.map((s, i) => {
                    const Icon = s.icon;
                    const isActive = i <= currentIndex;
                    const isComplete = i < currentIndex;
                    return (
                        <div key={s.id} className={`flex flex-col items-center gap-3 transition-opacity duration-300 ${isActive ? 'opacity-100' : 'opacity-25'}`}>
                            <div className="w-10 h-10 flex items-center justify-center" style={{
                                backgroundColor: isComplete ? C.greenBg : isActive ? '#EFF6FF' : C.bgAlt,
                                color: isComplete ? C.green : isActive ? C.navy : C.faint,
                            }}>
                                {isComplete ? <Check size={16} /> : <Icon size={16} strokeWidth={1.5} />}
                            </div>
                            <span className="text-[9px] text-center max-w-[80px] uppercase tracking-wider" style={{ color: C.faint }}>{s.label}</span>
                        </div>
                    );
                })}
            </div>
        </div>
    );
};

// ── File Upload Zone ──────────────────────────────────────────────
const UploadZone = ({ label, icon: Icon, accept, file, onFile }) => {
    const inputRef = useRef(null);
    const [dragOver, setDragOver] = useState(false);

    const handleDrop = (e) => {
        e.preventDefault();
        setDragOver(false);
        const f = e.dataTransfer.files[0];
        if (f) onFile(f);
    };

    return (
        <div
            className="flex-1 border-2 border-dashed p-6 text-center cursor-pointer transition-all duration-150"
            style={{
                borderColor: file ? C.green : dragOver ? C.navy : C.border,
                backgroundColor: file ? C.greenBg : dragOver ? '#F8FAFF' : C.bg,
            }}
            onClick={() => inputRef.current?.click()}
            onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
            onDragLeave={() => setDragOver(false)}
            onDrop={handleDrop}
        >
            <input
                ref={inputRef}
                type="file"
                accept={accept}
                className="hidden"
                onChange={(e) => { if (e.target.files[0]) onFile(e.target.files[0]); }}
            />
            <div className="flex flex-col items-center gap-3">
                {file ? (
                    <CheckCircle size={24} style={{ color: C.green }} />
                ) : (
                    <Icon size={24} style={{ color: C.faint }} strokeWidth={1.5} />
                )}
                <span className="text-[11px] tracking-[0.15em] uppercase font-medium" style={{ color: file ? C.green : C.navy }}>
                    {label}
                </span>
                {file ? (
                    <span className="text-[10px] tracking-wider" style={{ color: C.muted }}>
                        {file.name} ({(file.size / 1024).toFixed(1)} KB)
                    </span>
                ) : (
                    <span className="text-[10px] tracking-wider" style={{ color: C.faint }}>
                        Drop file or click to select
                    </span>
                )}
            </div>
        </div>
    );
};

// ── Main ShadowDiff Component ─────────────────────────────────────
const ShadowDiff = () => {
    // State
    const [phase, setPhase] = useState('upload'); // upload | processing | results
    const [processingStage, setProcessingStage] = useState('parsing');
    const [error, setError] = useState(null);

    // Upload state
    const [layoutFile, setLayoutFile] = useState(null);
    const [inputFile, setInputFile] = useState(null);
    const [outputFile, setOutputFile] = useState(null);
    const [pythonSource, setPythonSource] = useState('');

    // Results state
    const [result, setResult] = useState(null);
    const [detailsOpen, setDetailsOpen] = useState(false);
    const [mismatchPage, setMismatchPage] = useState(0);
    const [diagnosedPage, setDiagnosedPage] = useState(0);

    const token = localStorage.getItem('alethia_token');
    const authHeaders = { 'Authorization': `Bearer ${token}` };

    const canRun = layoutFile && inputFile && outputFile && pythonSource.trim();

    // ── Run Shadow Diff ───────────────────────────────────────────
    const runDiff = async (layoutData, inputBlob, outputBlob, python, layoutName) => {
        setPhase('processing');
        setProcessingStage('parsing');
        setError(null);

        const timers = [
            setTimeout(() => setProcessingStage('executing'), 1500),
            setTimeout(() => setProcessingStage('comparing'), 4000),
            setTimeout(() => setProcessingStage('reporting'), 7000),
        ];

        try {
            // Step 1: Upload layout
            const layoutRes = await fetch(apiUrl('/shadow-diff/upload-layout'), {
                method: 'POST',
                headers: { ...authHeaders, 'Content-Type': 'application/json' },
                body: JSON.stringify(layoutData),
            });
            if (!layoutRes.ok) throw new Error(`Layout upload failed (${layoutRes.status})`);

            // Step 2: Upload mainframe data
            const formData = new FormData();
            formData.append('input_file', inputBlob);
            formData.append('output_file', outputBlob);
            const dataRes = await fetch(
                apiUrl(`/shadow-diff/upload-mainframe-data?layout_name=${encodeURIComponent(layoutName)}`),
                { method: 'POST', headers: authHeaders, body: formData }
            );
            if (!dataRes.ok) throw new Error(`Data upload failed (${dataRes.status})`);

            // Step 3: Run diff
            const runBody = {
                layout_name: layoutName,
                generated_python: python,
            };
            if (layoutData.input_mapping) runBody.input_mapping = layoutData.input_mapping;
            if (layoutData.output_fields) runBody.output_fields = layoutData.output_fields;
            if (layoutData.constants) runBody.constants = layoutData.constants;

            const runRes = await fetch(apiUrl('/shadow-diff/run'), {
                method: 'POST',
                headers: { ...authHeaders, 'Content-Type': 'application/json' },
                body: JSON.stringify(runBody),
            });
            if (!runRes.ok) {
                const errData = await runRes.json().catch(() => ({}));
                throw new Error(errData.detail || `Diff run failed (${runRes.status})`);
            }

            const data = await runRes.json();
            setResult(data);
            setPhase('results');
        } catch (err) {
            setError(err.message);
            setPhase('upload');
        } finally {
            timers.forEach(clearTimeout);
        }
    };

    // ── Manual Run ────────────────────────────────────────────────
    const handleRun = async () => {
        try {
            const layoutText = await layoutFile.text();
            const layoutData = JSON.parse(layoutText);
            const layoutName = layoutData.name || layoutFile.name.replace('.json', '');
            await runDiff(layoutData, inputFile, outputFile, pythonSource, layoutName);
        } catch (err) {
            setError(`Failed to parse layout: ${err.message}`);
        }
    };

    // ── Demo Run ──────────────────────────────────────────────────
    const handleDemo = async () => {
        setError(null);
        try {
            // Fetch demo files from backend
            const [layoutRes, inputRes, outputRes, pythonRes] = await Promise.all([
                fetch(apiUrl('/demo-data/loan_layout.json')),
                fetch(apiUrl('/demo-data/loan_input.dat')),
                fetch(apiUrl('/demo-data/loan_mainframe_output.dat')),
                fetch(apiUrl('/demo-data/converted_loan_interest.py')),
            ]);

            if (!layoutRes.ok || !inputRes.ok || !outputRes.ok || !pythonRes.ok) {
                throw new Error('Failed to load demo data files');
            }

            const layoutData = await layoutRes.json();
            const inputText = await inputRes.text();
            const outputText = await outputRes.text();
            const pythonText = await pythonRes.text();

            // Create Blob files for upload
            const inputBlob = new Blob([inputText], { type: 'text/plain' });
            const outputBlob = new Blob([outputText], { type: 'text/plain' });

            // Set display state
            setLayoutFile(new File([JSON.stringify(layoutData)], 'loan_layout.json'));
            setInputFile(new File([inputText], 'loan_input.dat'));
            setOutputFile(new File([outputText], 'loan_mainframe_output.dat'));
            setPythonSource(pythonText);

            await runDiff(layoutData, inputBlob, outputBlob, pythonText, layoutData.name || 'DEMO-LOAN-INTEREST');
        } catch (err) {
            setError(`Demo failed: ${err.message}`);
        }
    };

    // ── Export Report ─────────────────────────────────────────────
    const handleExport = () => {
        if (!result) return;
        const blob = new Blob([JSON.stringify(result, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `shadow-diff-report-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    };

    // ── Reset ─────────────────────────────────────────────────────
    const handleReset = () => {
        setPhase('upload');
        setResult(null);
        setLayoutFile(null);
        setInputFile(null);
        setOutputFile(null);
        setPythonSource('');
        setError(null);
        setDetailsOpen(false);
        setMismatchPage(0);
        setDiagnosedPage(0);
    };

    // ══════════════════════════════════════════════════════════════
    // RENDER: Processing Phase
    // ══════════════════════════════════════════════════════════════
    if (phase === 'processing') {
        return <DiffLoader stage={processingStage} />;
    }

    // ══════════════════════════════════════════════════════════════
    // RENDER: Results Phase
    // ══════════════════════════════════════════════════════════════
    if (phase === 'results' && result) {
        const isZeroDrift = result.mismatches === 0;
        const mismatches = result.mismatch_log || [];
        const PAGE_SIZE = 50;

        const mismatchPageCount = Math.ceil(mismatches.length / PAGE_SIZE);
        const mismatchSlice = mismatches.slice(mismatchPage * PAGE_SIZE, (mismatchPage + 1) * PAGE_SIZE);

        const diagnosed = result.diagnosed_mismatches || [];
        const diagnosedPageCount = Math.ceil(diagnosed.length / PAGE_SIZE);
        const diagnosedSlice = diagnosed.slice(diagnosedPage * PAGE_SIZE, (diagnosedPage + 1) * PAGE_SIZE);

        return (
            <div className="max-w-5xl mx-auto px-6 py-8 space-y-8 fade-in">
                {/* Verdict Badge */}
                <div className="text-center py-10">
                    <div
                        className="inline-flex items-center gap-4 px-10 py-5"
                        style={{
                            backgroundColor: isZeroDrift ? C.green : C.red,
                        }}
                    >
                        {isZeroDrift
                            ? <CheckCircle size={28} className="text-white" />
                            : <XCircle size={28} className="text-white" />
                        }
                        <span className="text-white text-lg font-medium tracking-[0.3em] uppercase">
                            {isZeroDrift ? 'Zero Drift Confirmed' : `Drift Detected — ${result.mismatches} Records`}
                        </span>
                    </div>
                </div>

                {/* Stats Row */}
                <div className="grid grid-cols-3 gap-6">
                    {[
                        { label: 'Records Processed', value: result.total_records },
                        { label: 'Matches', value: result.matches, color: C.green },
                        { label: 'Mismatches', value: result.mismatches, color: result.mismatches > 0 ? C.red : C.green },
                    ].map((stat) => (
                        <div key={stat.label} className="border p-6 text-center" style={{ borderColor: C.border }}>
                            <div className="text-3xl font-light mb-2" style={{ color: stat.color || C.text }}>
                                {stat.value}
                            </div>
                            <div className="text-[10px] tracking-[0.2em] uppercase" style={{ color: C.faint }}>
                                {stat.label}
                            </div>
                        </div>
                    ))}
                </div>

                {/* Mismatch Table */}
                {mismatches.length > 0 && (
                    <div className="border" style={{ borderColor: C.border }}>
                        <div className="px-6 py-4 border-b" style={{ borderColor: C.border, backgroundColor: C.redBg }}>
                            <h3 className="text-[13px] font-semibold tracking-[0.15em] uppercase" style={{ color: C.red }}>
                                Mismatch Detail
                            </h3>
                        </div>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead>
                                    <tr style={{ backgroundColor: C.bgAlt }}>
                                        {['Record #', 'Field', 'Aletheia Value', 'Mainframe Value', 'Difference'].map(h => (
                                            <th key={h} className="px-4 py-3 text-left text-[10px] tracking-[0.15em] uppercase font-medium"
                                                style={{ color: C.faint, borderBottom: `1px solid ${C.border}` }}>
                                                {h}
                                            </th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {mismatchSlice.map((m, i) => (
                                        <tr key={i} style={{ borderLeft: `3px solid ${C.red}` }}>
                                            <td className="px-4 py-3 font-mono text-xs" style={{ color: C.text, borderBottom: `1px solid ${C.borderLight}` }}>
                                                {m.record}
                                            </td>
                                            <td className="px-4 py-3 font-mono text-xs" style={{ color: C.text, borderBottom: `1px solid ${C.borderLight}` }}>
                                                {m.field}
                                            </td>
                                            <td className="px-4 py-3 font-mono text-xs" style={{ color: C.text, borderBottom: `1px solid ${C.borderLight}` }}>
                                                {m.aletheia_value}
                                            </td>
                                            <td className="px-4 py-3 font-mono text-xs" style={{ color: C.text, borderBottom: `1px solid ${C.borderLight}` }}>
                                                {m.mainframe_value}
                                            </td>
                                            <td className="px-4 py-3 font-mono text-xs" style={{ color: C.red, borderBottom: `1px solid ${C.borderLight}` }}>
                                                {m.difference}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                        {mismatchPageCount > 1 && (
                            <div className="flex items-center justify-between px-6 py-3 border-t" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                                <span className="text-[10px] tracking-[0.15em] uppercase font-medium" style={{ color: C.faint }}>
                                    Showing {mismatchPage * PAGE_SIZE + 1}&ndash;{Math.min((mismatchPage + 1) * PAGE_SIZE, mismatches.length)} of {mismatches.length}
                                </span>
                                <div className="flex items-center gap-3">
                                    <button
                                        onClick={() => setMismatchPage(p => p - 1)}
                                        disabled={mismatchPage === 0}
                                        className="px-3 py-1 border text-[10px] tracking-[0.15em] uppercase font-medium transition-colors duration-150"
                                        style={{ borderColor: C.border, color: mismatchPage === 0 ? C.faint : C.navy, opacity: mismatchPage === 0 ? 0.4 : 1 }}
                                    >Prev</button>
                                    <span className="text-[10px] tracking-[0.15em] uppercase font-medium" style={{ color: C.navy }}>
                                        Page {mismatchPage + 1} of {mismatchPageCount}
                                    </span>
                                    <button
                                        onClick={() => setMismatchPage(p => p + 1)}
                                        disabled={mismatchPage >= mismatchPageCount - 1}
                                        className="px-3 py-1 border text-[10px] tracking-[0.15em] uppercase font-medium transition-colors duration-150"
                                        style={{ borderColor: C.border, color: mismatchPage >= mismatchPageCount - 1 ? C.faint : C.navy, opacity: mismatchPage >= mismatchPageCount - 1 ? 0.4 : 1 }}
                                    >Next</button>
                                </div>
                            </div>
                        )}
                    </div>
                )}

                {/* Diagnosed Mismatches */}
                {diagnosed.length > 0 && (
                    <div className="border" style={{ borderColor: C.border }}>
                        <div className="px-6 py-4 border-b" style={{ borderColor: C.border, backgroundColor: C.amberBg }}>
                            <h3 className="text-[13px] font-semibold tracking-[0.15em] uppercase" style={{ color: C.amber }}>
                                Root-Cause Analysis
                            </h3>
                        </div>
                        <div className="divide-y" style={{ borderColor: C.borderLight }}>
                            {diagnosedSlice.map((d, i) => (
                                <div key={i} className="px-6 py-4" style={{ borderLeft: `3px solid ${C.amber}`, backgroundColor: i % 2 === 0 ? C.bg : C.bgAlt }}>
                                    <div className="flex items-baseline gap-4 mb-2">
                                        <span className="font-mono text-xs px-2 py-0.5" style={{ backgroundColor: C.bgAlt, color: C.text }}>
                                            Record {d.record}
                                        </span>
                                        <span className="font-mono text-xs" style={{ color: C.navy }}>{d.field}</span>
                                        {d.magnitude && (
                                            <span className="text-[10px] tracking-wider" style={{ color: C.red }}>
                                                {'\u0394'} {d.magnitude}
                                            </span>
                                        )}
                                    </div>
                                    <div className="text-xs mb-1" style={{ color: C.text }}>
                                        <span className="font-medium" style={{ color: C.amber }}>Cause: </span>
                                        {d.likely_cause}
                                    </div>
                                    <div className="text-xs" style={{ color: C.muted }}>
                                        <span className="font-medium" style={{ color: C.navy }}>Fix: </span>
                                        {d.suggested_fix}
                                    </div>
                                </div>
                            ))}
                        </div>
                        {diagnosedPageCount > 1 && (
                            <div className="flex items-center justify-between px-6 py-3 border-t" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                                <span className="text-[10px] tracking-[0.15em] uppercase font-medium" style={{ color: C.faint }}>
                                    Showing {diagnosedPage * PAGE_SIZE + 1}&ndash;{Math.min((diagnosedPage + 1) * PAGE_SIZE, diagnosed.length)} of {diagnosed.length}
                                </span>
                                <div className="flex items-center gap-3">
                                    <button
                                        onClick={() => setDiagnosedPage(p => p - 1)}
                                        disabled={diagnosedPage === 0}
                                        className="px-3 py-1 border text-[10px] tracking-[0.15em] uppercase font-medium transition-colors duration-150"
                                        style={{ borderColor: C.border, color: diagnosedPage === 0 ? C.faint : C.navy, opacity: diagnosedPage === 0 ? 0.4 : 1 }}
                                    >Prev</button>
                                    <span className="text-[10px] tracking-[0.15em] uppercase font-medium" style={{ color: C.navy }}>
                                        Page {diagnosedPage + 1} of {diagnosedPageCount}
                                    </span>
                                    <button
                                        onClick={() => setDiagnosedPage(p => p + 1)}
                                        disabled={diagnosedPage >= diagnosedPageCount - 1}
                                        className="px-3 py-1 border text-[10px] tracking-[0.15em] uppercase font-medium transition-colors duration-150"
                                        style={{ borderColor: C.border, color: diagnosedPage >= diagnosedPageCount - 1 ? C.faint : C.navy, opacity: diagnosedPage >= diagnosedPageCount - 1 ? 0.4 : 1 }}
                                    >Next</button>
                                </div>
                            </div>
                        )}
                    </div>
                )}

                {/* Report Details (Collapsible) */}
                <div className="border" style={{ borderColor: C.border }}>
                    <button
                        onClick={() => setDetailsOpen(!detailsOpen)}
                        className="w-full flex items-center gap-4 px-6 py-5 text-left"
                    >
                        <FileJson size={16} strokeWidth={1.5} style={{ color: C.faint }} />
                        <span className="flex-1 text-[13px] font-semibold uppercase tracking-[0.15em]" style={{ color: C.navy }}>
                            Report Details
                        </span>
                        <ChevronDown size={16} style={{ color: C.faint }}
                            className={`transition-transform duration-200 ${detailsOpen ? 'rotate-180' : ''}`} />
                    </button>
                    {detailsOpen && (
                        <div className="px-6 pb-6 space-y-3 border-t" style={{ borderColor: C.border }}>
                            <div className="pt-4 grid grid-cols-2 gap-4">
                                {[
                                    { label: 'Timestamp', value: result.timestamp },
                                    { label: 'Layout', value: result.layout_name },
                                    { label: 'Input Fingerprint', value: result.input_file_hash },
                                    { label: 'Output Fingerprint', value: result.output_file_hash },
                                ].map(d => (
                                    <div key={d.label}>
                                        <div className="text-[10px] tracking-[0.15em] uppercase mb-1" style={{ color: C.faint }}>{d.label}</div>
                                        <div className="font-mono text-xs break-all" style={{ color: C.text }}>{d.value}</div>
                                    </div>
                                ))}
                            </div>
                            <div>
                                <div className="text-[10px] tracking-[0.15em] uppercase mb-1" style={{ color: C.faint }}>Verdict</div>
                                <div className="font-mono text-xs" style={{ color: C.text }}>{result.verdict}</div>
                            </div>
                        </div>
                    )}
                </div>

                {/* Action Buttons */}
                <div className="flex flex-wrap gap-4">
                    <button
                        onClick={handleExport}
                        className="flex items-center gap-2 px-6 py-3 border text-sm tracking-[0.1em] uppercase transition-colors duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.navy }}
                    >
                        <Download size={14} strokeWidth={1.5} />
                        Export JSON
                    </button>
                    <button
                        onClick={() => generateShadowDiffPDF(result, 'executive')}
                        className="flex items-center gap-2 px-6 py-3 border text-sm tracking-[0.1em] uppercase transition-colors duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.navy }}
                    >
                        <Download size={14} strokeWidth={1.5} />
                        Export PDF (Executive)
                    </button>
                    <button
                        onClick={() => generateShadowDiffPDF(result, 'engineer')}
                        className="flex items-center gap-2 px-6 py-3 border text-sm tracking-[0.1em] uppercase transition-colors duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.navy }}
                    >
                        <Download size={14} strokeWidth={1.5} />
                        Export PDF (Engineer)
                    </button>
                    <button
                        onClick={handleReset}
                        className="flex items-center gap-2 px-6 py-3 border text-sm tracking-[0.1em] uppercase transition-colors duration-150 hover:shadow-sm"
                        style={{ borderColor: C.border, color: C.faint }}
                    >
                        <RotateCcw size={14} strokeWidth={1.5} />
                        New Diff
                    </button>
                </div>
            </div>
        );
    }

    // ══════════════════════════════════════════════════════════════
    // RENDER: Upload Phase
    // ══════════════════════════════════════════════════════════════
    return (
        <div className="max-w-5xl mx-auto px-6 py-8 space-y-8 fade-in">
            {/* Header */}
            <div className="text-center space-y-3 pb-4">
                <h2 className="text-base font-medium tracking-[0.25em] uppercase" style={{ color: C.navy }}>
                    Shadow Diff — Mainframe I/O Replay
                </h2>
                <p className="text-[11px] tracking-[0.2em] uppercase" style={{ color: C.faint }}>
                    Compare Aletheia output against real mainframe data
                </p>
            </div>

            {/* Demo Button */}
            <div className="text-center">
                <button
                    onClick={handleDemo}
                    className="inline-flex items-center gap-3 px-8 py-4 border text-sm tracking-[0.2em] uppercase transition-all duration-150 hover:shadow-md"
                    style={{ borderColor: C.navy, color: C.navy }}
                >
                    <Zap size={16} strokeWidth={1.5} />
                    Run Demo
                </button>
                <p className="text-[10px] tracking-wider mt-3" style={{ color: C.faint }}>
                    100 loan records &middot; DEMO_LOAN_INTEREST.cbl
                </p>
            </div>

            {/* Separator */}
            <div className="flex items-center gap-4">
                <div className="flex-1 h-px" style={{ backgroundColor: C.border }} />
                <span className="text-[10px] tracking-[0.2em] uppercase" style={{ color: C.faint }}>or upload your own</span>
                <div className="flex-1 h-px" style={{ backgroundColor: C.border }} />
            </div>

            {/* Upload Zones */}
            <div className="flex flex-col md:flex-row gap-4">
                <UploadZone
                    label="Layout Definition"
                    icon={FileJson}
                    accept=".json"
                    file={layoutFile}
                    onFile={setLayoutFile}
                />
                <UploadZone
                    label="Mainframe Input"
                    icon={Upload}
                    accept=".dat,.txt"
                    file={inputFile}
                    onFile={setInputFile}
                />
                <UploadZone
                    label="Mainframe Output"
                    icon={FileText}
                    accept=".dat,.txt"
                    file={outputFile}
                    onFile={setOutputFile}
                />
            </div>

            {/* Python Source */}
            <div>
                <label className="block text-[11px] tracking-[0.15em] uppercase mb-2 font-medium" style={{ color: C.navy }}>
                    Generated Python (Verification Model)
                </label>
                <textarea
                    value={pythonSource}
                    onChange={(e) => setPythonSource(e.target.value)}
                    placeholder="Paste the Aletheia-generated Python code here..."
                    className="w-full h-40 px-4 py-3 font-mono text-xs border resize-none focus:outline-none focus:ring-1"
                    style={{
                        borderColor: C.border,
                        color: C.text,
                        backgroundColor: C.bgAlt,
                        focusRingColor: C.navy,
                    }}
                />
            </div>

            {/* Error */}
            {error && (
                <div className="px-5 py-4 border-l-4" style={{ borderColor: C.red, backgroundColor: C.redBg }}>
                    <p className="text-sm" style={{ color: C.red }}>{error}</p>
                </div>
            )}

            {/* Run Button */}
            <div className="text-center pt-2">
                <button
                    onClick={handleRun}
                    disabled={!canRun}
                    className="inline-flex items-center gap-3 px-8 py-4 text-white text-sm tracking-[0.2em] uppercase transition-all duration-150"
                    style={{
                        backgroundColor: canRun ? C.navy : C.border,
                        cursor: canRun ? 'pointer' : 'not-allowed',
                    }}
                >
                    <Play size={16} strokeWidth={1.5} />
                    Run Shadow Diff
                </button>
            </div>
        </div>
    );
};

export default ShadowDiff;
