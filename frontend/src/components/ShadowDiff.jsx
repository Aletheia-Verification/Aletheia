import React, { useState, useRef } from 'react';
import {
    GitCompareArrows, Upload, FileJson, FileText, Cpu,
    CheckCircle, XCircle, Download, RotateCcw,
    Play, Zap, ShieldCheck, Check
} from 'lucide-react';
import { apiUrl } from '../config/api';
import { generateShadowDiffPDF } from '../utils/shadowDiffPdf';
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts';
import { useColors, LIGHT } from '../hooks/useColors';

// ── Processing Loader ─────────────────────────────────────────────
const DiffLoader = ({ stage, C, statusText }) => {
    if (!C) C = LIGHT;
    const stages = [
        { id: 'parsing', label: 'Analyzing COBOL', icon: Cpu },
        { id: 'executing', label: 'Uploading Data', icon: Upload },
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
                <h2 className="text-base font-medium tracking-[0.2em] uppercase" style={{ color: C.text }}>Verifying</h2>
                <p className="text-xs tracking-[0.15em] uppercase" style={{ color: C.faint }}>
                    {statusText || stages[currentIndex >= 0 ? currentIndex : 0].label}
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
const UploadZone = ({ label, icon: Icon, accept, file, onFile, C }) => {
    if (!C) C = LIGHT;
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
const ShadowDiff = ({ onNavigate }) => {
    const C = useColors() || LIGHT;
    // State
    const [phase, setPhase] = useState('upload'); // upload | processing | results
    const [processingStage, setProcessingStage] = useState('parsing');
    const [error, setError] = useState(null);
    const [statusText, setStatusText] = useState('');

    // Upload state — 3-input flow
    const [cobolSource, setCobolSource] = useState('');
    const [cobolFileName, setCobolFileName] = useState('');
    const [mainframeFile, setMainframeFile] = useState(null);
    const [migratedFile, setMigratedFile] = useState(null);
    const [layoutStatus, setLayoutStatus] = useState(null);
    const [cachedLayout, setCachedLayout] = useState(null);
    const [manualLayout, setManualLayout] = useState('');
    // Legacy state for backwards compat with runDiff
    const [layoutFile, setLayoutFile] = useState(null);
    const [inputFile, setInputFile] = useState(null);
    const [outputFile, setOutputFile] = useState(null);
    const [pythonSource, setPythonSource] = useState('');

    // Results state
    const [result, setResult] = useState(null);
    const [mismatchPage, setMismatchPage] = useState(0);

    useKeyboardShortcuts({
        onExportPdf: () => { if (result) generateShadowDiffPDF(result, 'executive'); },
    });
    const [diagnosedPage, setDiagnosedPage] = useState(0);
    const [demoLoading, setDemoLoading] = useState(false);

    const authHeaders = {};

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
            // Upload layout
            setStatusText('Uploading layout...');
            const layoutRes = await fetch(apiUrl('/shadow-diff/upload-layout'), {
                method: 'POST',
                headers: { ...authHeaders, 'Content-Type': 'application/json' },
                body: JSON.stringify(layoutData),
            });
            if (!layoutRes.ok) throw new Error(`Layout upload failed (${layoutRes.status})`);

            // Upload mainframe data
            setStatusText('Step 4/5: Uploading data files...');
            setProcessingStage('executing');
            const formData = new FormData();
            formData.append('input_file', inputBlob, 'input.dat');
            formData.append('output_file', outputBlob, 'output.dat');
            const dataRes = await fetch(
                apiUrl(`/shadow-diff/upload-mainframe-data?layout_name=${encodeURIComponent(layoutName)}`),
                { method: 'POST', headers: authHeaders, body: formData }
            );
            if (!dataRes.ok) throw new Error(`Data upload failed (${dataRes.status})`);

            // Run comparison
            setStatusText('Step 5/5: Comparing outputs...');
            setProcessingStage('comparing');
            const runBody = {
                layout_name: layoutName,
                generated_python: python,
            };
            if (layoutData.input_mapping) runBody.input_mapping = layoutData.input_mapping;
            const of = layoutData.output_fields || layoutData.fields;
            if (of && of.length > 0) runBody.output_fields = of;
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
        setDemoLoading(true);
        try {
            // Fetch demo data files and COBOL source in parallel
            const [layoutRes, inputRes, outputRes, cobolRes] = await Promise.all([
                fetch(apiUrl('/demo-data/loan_layout.json')),
                fetch(apiUrl('/demo-data/loan_input.dat')),
                fetch(apiUrl('/demo-data/loan_mainframe_output.dat')),
                fetch(apiUrl('/demo-data/DEMO_LOAN_INTEREST.cbl')),
            ]);

            if (!layoutRes.ok || !inputRes.ok || !outputRes.ok || !cobolRes.ok) {
                throw new Error('Failed to load demo data files');
            }

            const layoutData = await layoutRes.json();
            const inputText = await inputRes.text();
            const outputText = await outputRes.text();
            const cobolSource = await cobolRes.text();

            // Generate Python live via the engine
            const analyzeRes = await fetch(apiUrl('/engine/analyze'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    cobol_code: cobolSource,
                    filename: 'DEMO_LOAN_INTEREST.cbl',
                }),
            });

            if (!analyzeRes.ok) {
                const err = await analyzeRes.json().catch(() => ({}));
                throw new Error(err.detail || `Engine analysis failed (${analyzeRes.status})`);
            }

            const analyzeData = await analyzeRes.json();
            const pythonText = analyzeData.generated_python;
            if (!pythonText) {
                throw new Error('Engine did not return generated Python');
            }

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
        } finally {
            setDemoLoading(false);
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

    // ── Auto-Layout Check ─────────────────────────────────────────
    const checkLayout = async (source) => {
        try {
            const res = await fetch(apiUrl('/engine/generate-layout'), {
                method: 'POST',
                headers: { ...authHeaders, 'Content-Type': 'application/json' },
                body: JSON.stringify({ cobol_code: source }),
            });
            if (res.ok) {
                const data = await res.json();
                const fieldCount = data?.fields?.length || 0;
                if (fieldCount > 0) {
                    setLayoutStatus({ fields: fieldCount });
                    setCachedLayout(data);
                } else {
                    setLayoutStatus('failed');
                    setCachedLayout(null);
                }
            } else {
                setLayoutStatus('failed');
                setCachedLayout(null);
            }
        } catch {
            setLayoutStatus('failed');
            setCachedLayout(null);
        }
    };

    const handleCobolUpload = async (file) => {
        const text = await file.text();
        setCobolSource(text);
        setCobolFileName(file.name);
        checkLayout(text);
    };

    // ── 3-Input Verify (5-call chain) ───────────────────────────
    const handleVerify = async () => {
        setPhase('processing');
        setProcessingStage('parsing');
        setError(null);

        const timers = [
            setTimeout(() => setProcessingStage('executing'), 3000),
            setTimeout(() => setProcessingStage('comparing'), 8000),
            setTimeout(() => setProcessingStage('reporting'), 14000),
        ];

        try {
            // Step 1/5: Analyze COBOL
            setStatusText('Step 1/5: Analyzing COBOL...');
            setProcessingStage('parsing');
            const analyzeRes = await fetch(apiUrl('/engine/analyze'), {
                method: 'POST',
                headers: { ...authHeaders, 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cobol_code: cobolSource,
                    filename: cobolFileName || 'source.cbl',
                }),
            });
            if (!analyzeRes.ok) throw new Error('Analysis failed: ' + (await analyzeRes.json().catch(() => ({}))).detail);
            const analysis = await analyzeRes.json();
            const generatedPython = analysis.generated_python;
            if (!generatedPython) throw new Error('Engine did not return generated Python');

            // Step 2/5: Generate layout
            setStatusText('Step 2/5: Generating layout...');
            let layout = cachedLayout;
            if (!layout && manualLayout.trim()) {
                try { layout = JSON.parse(manualLayout); } catch { throw new Error('Invalid layout JSON'); }
            }
            if (!layout) {
                const layoutRes = await fetch(apiUrl('/engine/generate-layout'), {
                    method: 'POST',
                    headers: { ...authHeaders, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ cobol_code: cobolSource }),
                });
                if (layoutRes.ok) layout = await layoutRes.json();
            }
            if (!layout || !layout.fields?.length) throw new Error('Could not generate layout from COBOL source.');

            const layoutName = layout.name || 'auto-layout';

            // Step 3/5: Upload layout
            setStatusText('Step 3/5: Uploading layout...');
            setProcessingStage('executing');

            // Step 4/5 + 5/5: Run Shadow Diff via existing runDiff
            setStatusText('Step 4/5: Uploading data files...');
            await runDiff(layout, mainframeFile, migratedFile, generatedPython, layoutName);
        } catch (err) {
            setError(err.message);
            setPhase('upload');
        } finally {
            timers.forEach(clearTimeout);
        }
    };

    const canVerify = cobolSource.trim() && mainframeFile && migratedFile;

    // ── Reset ─────────────────────────────────────────────────────
    const handleReset = () => {
        setPhase('upload');
        setResult(null);
        setCobolSource('');
        setCobolFileName('');
        setMainframeFile(null);
        setMigratedFile(null);
        setLayoutStatus(null);
        setCachedLayout(null);
        setManualLayout('');
        setLayoutFile(null);
        setInputFile(null);
        setOutputFile(null);
        setPythonSource('');
        setError(null);
        setMismatchPage(0);
        setDiagnosedPage(0);
    };

    // ══════════════════════════════════════════════════════════════
    // RENDER: Processing Phase
    // ══════════════════════════════════════════════════════════════
    if (phase === 'processing') {
        return <DiffLoader stage={processingStage} C={C} statusText={statusText} />;
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

        const matchRate = result.total_records > 0
            ? ((result.matches / result.total_records) * 100).toFixed(1)
            : '0.0';
        const outputFields = result.output_fields || [];

        return (
            <div className="max-w-5xl mx-auto px-6 py-8 fade-in">

                {/* ═══ HERO: Verdict ═══ */}
                <div className="mb-10 pb-10 pt-12 border-b" style={{ borderColor: C.border }}>
                    <div className="flex items-center justify-between mb-8">
                        <div className="flex items-center gap-5">
                            <div className="w-14 h-14 flex items-center justify-center" style={{
                                backgroundColor: isZeroDrift ? C.greenBg : C.redBg,
                            }}>
                                {isZeroDrift
                                    ? <CheckCircle size={28} strokeWidth={1.5} style={{ color: C.green }} />
                                    : <XCircle size={28} strokeWidth={1.5} style={{ color: C.red }} />
                                }
                            </div>
                            <div>
                                <h2 className="text-xl font-semibold tracking-[0.08em] uppercase" style={{ color: C.text }}>
                                    {isZeroDrift ? 'Zero Drift Confirmed' : 'Drift Detected'}
                                </h2>
                                <p className="text-[11px] mt-1 tracking-wide" style={{ color: C.faint }}>
                                    {result.layout_name || 'Shadow Diff Verification'}
                                </p>
                            </div>
                        </div>
                        <div className="px-8 py-3.5 text-base font-bold uppercase tracking-widest" style={{
                            backgroundColor: isZeroDrift ? C.navy : C.bg,
                            color: isZeroDrift ? '#FFFFFF' : C.red,
                            border: isZeroDrift ? 'none' : `2px solid ${C.redBorder}`,
                        }}>
                            {isZeroDrift ? 'ZERO DRIFT' : `${result.mismatches} MISMATCHES`}
                        </div>
                    </div>

                    {/* Description line */}
                    <p className="text-[13px] leading-relaxed" style={{ color: C.muted }}>
                        {isZeroDrift
                            ? `All ${result.total_records} records produced identical outputs to the mainframe.`
                            : `${result.mismatches} of ${result.total_records} records showed behavioral divergence requiring investigation.`
                        }
                    </p>

                    {/* Stats Row */}
                    <div className="flex items-center gap-6 text-[12px] mt-6" style={{ color: C.muted }}>
                        <span><strong style={{ color: C.text }}>{result.total_records}</strong> Records</span>
                        <span style={{ color: C.border }}>|</span>
                        <span><strong style={{ color: C.green }}>{result.matches}</strong> Matches</span>
                        <span style={{ color: C.border }}>|</span>
                        <span><strong style={{ color: result.mismatches > 0 ? C.red : C.green }}>{result.mismatches}</strong> Mismatches</span>
                        <span style={{ color: C.border }}>|</span>
                        <span><strong style={{ color: C.text }}>{result.abends ?? 0}</strong> S0C7 Abends</span>
                        <span style={{ color: C.border }}>|</span>
                        <span><strong style={{ color: isZeroDrift ? C.green : C.amber }}>{matchRate}%</strong> Match Rate</span>
                    </div>
                </div>

                {/* ═══ Verification Summary ═══ */}
                {isZeroDrift ? (
                    <div className="mb-12 p-8 border-l-[3px]" style={{ borderColor: C.navy, backgroundColor: '#FAFBFC' }}>
                        <p className="text-[16px] leading-[1.8] max-w-[900px]" style={{ color: C.body }}>
                            The generated Python produced mathematically identical outputs to the mainframe across
                            all {result.total_records} records.
                            {outputFields.length > 0 && (
                                <> Fields verified: {outputFields.join(', ')}.</>
                            )}
                            {' '}Input file hash and output file hash are cryptographically fingerprinted below.
                        </p>
                    </div>
                ) : (
                    <>
                        {/* Root-Cause Analysis — promoted to top for drift */}
                        {diagnosed.length > 0 && (
                            <div className="mb-10 border" style={{ borderColor: C.border }}>
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

                        {/* Drift summary text */}
                        <div className="mb-10 p-8 border-l-[3px]" style={{ borderColor: C.red, backgroundColor: C.redBg }}>
                            <p className="text-[16px] leading-[1.8] max-w-[900px]" style={{ color: C.body }}>
                                {result.mismatches} of {result.total_records} records showed behavioral divergence.
                                {diagnosed.length > 0
                                    ? ` Root-cause analysis identified ${diagnosed.length} diagnosed mismatch${diagnosed.length !== 1 ? 'es' : ''} above.`
                                    : ' Review the mismatch detail below for field-level differences.'
                                }
                            </p>
                        </div>
                    </>
                )}

                {/* ═══ Mismatch Table ═══ */}
                {mismatches.length > 0 && (
                    <div className="mb-10 border" style={{ borderColor: C.border }}>
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

                {/* ═══ Report Details (always open) ═══ */}
                <div className="mb-10 border" style={{ borderColor: C.border }}>
                    <div className="px-6 py-4 border-b flex items-center gap-4" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                        <FileJson size={16} strokeWidth={1.5} style={{ color: C.faint }} />
                        <h3 className="text-[13px] font-semibold tracking-[0.15em] uppercase" style={{ color: C.navy }}>
                            Report Details
                        </h3>
                    </div>
                    <div className="px-6 py-6">
                        <div className="grid grid-cols-2 gap-6">
                            {[
                                { label: 'Timestamp', value: result.timestamp },
                                { label: 'Layout', value: result.layout_name },
                                { label: 'Verdict', value: result.verdict },
                                { label: 'Records Processed', value: result.total_records },
                            ].map(d => (
                                <div key={d.label}>
                                    <div className="text-[9px] uppercase tracking-[0.12em] mb-1.5" style={{ color: C.faint }}>{d.label}</div>
                                    <div className="font-mono text-xs" style={{ color: C.text }}>{d.value}</div>
                                </div>
                            ))}
                        </div>
                        <div className="mt-6 pt-6 border-t space-y-4" style={{ borderColor: C.borderLight }}>
                            <div>
                                <div className="text-[9px] uppercase tracking-[0.12em] mb-1.5" style={{ color: C.faint }}>Input File Fingerprint</div>
                                <div className="font-mono text-[11px] break-all px-3 py-2" style={{ color: C.text, backgroundColor: C.bgAlt }}>{result.input_file_hash}</div>
                            </div>
                            <div>
                                <div className="text-[9px] uppercase tracking-[0.12em] mb-1.5" style={{ color: C.faint }}>Output File Fingerprint</div>
                                <div className="font-mono text-[11px] break-all px-3 py-2" style={{ color: C.text, backgroundColor: C.bgAlt }}>{result.output_file_hash}</div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* ═══ Action Buttons ═══ */}
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
    // RENDER: Upload Phase — 3-Input Flow
    // ══════════════════════════════════════════════════════════════
    return (
        <div className="max-w-2xl mx-auto px-6 py-8 space-y-10 fade-in">
            {/* Header */}
            <div className="text-center space-y-3">
                <h2 className="text-lg font-medium" style={{ color: C.text }}>
                    Verify Migration
                </h2>
                <p className="text-sm" style={{ color: C.muted }}>
                    Prove your migration matches the mainframe. Field by field.
                </p>
            </div>


            {/* Step 1: COBOL Source */}
            <div>
                <label className="text-[11px] tracking-wider uppercase mb-2 block font-medium" style={{ color: C.muted }}>
                    1. COBOL Source
                </label>
                <UploadZone
                    label="COBOL Program"
                    icon={Cpu}
                    accept=".cbl,.cob,.cobol,.CBL,.COB"
                    file={cobolFileName ? { name: cobolFileName, size: cobolSource.length } : null}
                    onFile={handleCobolUpload}
                    C={C}
                />
                {layoutStatus && layoutStatus !== 'failed' && (
                    <div className="mt-2 text-[11px] flex items-center gap-1.5" style={{ color: C.green }}>
                        <Check size={12} /> Layout auto-detected: {layoutStatus.fields} fields
                    </div>
                )}
                {layoutStatus === 'failed' && (
                    <div className="mt-3">
                        <p className="text-[11px] mb-2" style={{ color: '#D97706' }}>
                            Could not detect layout from COBOL. Paste field definitions:
                        </p>
                        <textarea
                            value={manualLayout}
                            onChange={e => setManualLayout(e.target.value)}
                            className="w-full h-24 font-mono text-[11px] p-3 rounded-lg border resize-none focus:outline-none"
                            style={{ borderColor: C.border, backgroundColor: C.bgAlt, color: C.text }}
                            placeholder='{"name": "MY-LAYOUT", "fields": [{"name": "FIELD-A", "start": 0, "length": 10, "type": "string"}]}'
                        />
                    </div>
                )}
            </div>

            {/* Step 2: Mainframe Output */}
            <div>
                <label className="text-[11px] tracking-wider uppercase mb-1 block font-medium" style={{ color: C.muted }}>
                    2. Mainframe Output
                </label>
                <p className="text-[11px] mb-2" style={{ color: C.faint }}>The original system's results</p>
                <UploadZone
                    label="Mainframe Output"
                    icon={Upload}
                    accept=".dat,.txt,.out"
                    file={mainframeFile}
                    onFile={setMainframeFile}
                    C={C}
                />
            </div>

            {/* Step 3: Migrated Output */}
            <div>
                <label className="text-[11px] tracking-wider uppercase mb-1 block font-medium" style={{ color: C.muted }}>
                    3. Migrated Output
                </label>
                <p className="text-[11px] mb-2" style={{ color: C.faint }}>The new system's results</p>
                <UploadZone
                    label="Migrated Output"
                    icon={FileText}
                    accept=".dat,.txt,.out"
                    file={migratedFile}
                    onFile={setMigratedFile}
                    C={C}
                />
            </div>

            {/* Error */}
            {error && (
                <div className="px-5 py-4 border-l-4 rounded" style={{ borderColor: C.red, backgroundColor: C.redBg }}>
                    <p className="text-sm" style={{ color: C.red }}>{error}</p>
                </div>
            )}

            {/* Verify Button */}
            <div className="text-center pt-2">
                <button
                    onClick={handleVerify}
                    disabled={!canVerify}
                    className="w-full py-3.5 text-[12px] tracking-wider uppercase font-medium rounded-lg transition-all duration-150"
                    style={{
                        backgroundColor: canVerify ? C.navy : C.border,
                        color: canVerify ? 'white' : C.muted,
                        cursor: canVerify ? 'pointer' : 'not-allowed',
                    }}
                >
                    Verify
                </button>
            </div>
        </div>
    );
};

export default ShadowDiff;
