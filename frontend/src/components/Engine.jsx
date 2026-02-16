import { useState, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Code2,
    FileText,
    Copy,
    Download,
    ChevronRight,
    ChevronDown,
    Cpu,
    BrainCircuit,
    ShieldCheck,
    Check,
    CloudUpload,
    MessageSquare,
    AlertTriangle,
    CheckCircle,
    XCircle,
    Clock
} from 'lucide-react';
import ExplanationChat from './ExplanationChat';
import { apiUrl } from '../config/api';
import { generateForensicPDF } from '../utils/pdfExport';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const MAX_PASTE_CHARS = 500000;

// ── Audit Confidence Badge ──────────────────────────────────────────
const AuditBadge = ({ audit }) => {
    if (!audit) return null;
    const cfg = {
        VERIFIED: { color: 'text-green-400 bg-green-500/10 border-green-500/30', Icon: CheckCircle },
        PROBABLE: { color: 'text-amber-400 bg-amber-500/10 border-amber-500/30', Icon: ShieldCheck },
        UNCERTAIN: { color: 'text-yellow-400 bg-yellow-500/10 border-yellow-500/30', Icon: AlertTriangle },
        UNRELIABLE: { color: 'text-red-400 bg-red-500/10 border-red-500/30', Icon: XCircle },
    };
    const { color, Icon } = cfg[audit.level] || cfg.UNCERTAIN;
    return (
        <div className={`inline-flex items-center gap-2 px-3 py-1.5 border text-[10px] font-mono uppercase tracking-widest ${color}`}>
            <Icon size={14} />
            <span>{audit.level}</span>
            <span className="opacity-60">({audit.confidence})</span>
        </div>
    );
};

// ── Audit Pipeline Stage (expandable) ───────────────────────────────
const AuditStage = ({ number, name, stage, isExpanded, onToggle }) => {
    if (!stage) return null;
    const passed = stage.success !== false;
    return (
        <div className="border border-border/50 overflow-hidden">
            <button
                onClick={onToggle}
                className="w-full flex items-center gap-3 px-4 py-3 bg-surface/30 hover:bg-surface/50 transition-colors text-left"
            >
                <span className={`w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold ${passed ? 'bg-green-500/15 text-green-400' : 'bg-red-500/15 text-red-400'}`}>
                    {passed ? '\u2713' : '\u2717'}
                </span>
                <span className="flex-1 text-[11px] font-mono uppercase tracking-wider text-text">
                    Stage {number}: {name}
                </span>
                {stage.confidence && (
                    <span className="text-[10px] font-mono text-primary">{stage.confidence}</span>
                )}
                {stage.execution_time_ms && (
                    <span className="text-[9px] font-mono text-text-dim flex items-center gap-1">
                        <Clock size={10} /> {stage.execution_time_ms}ms
                    </span>
                )}
                <ChevronDown size={14} className={`text-text-dim transition-transform ${isExpanded ? 'rotate-180' : ''}`} />
            </button>
            <AnimatePresence>
                {isExpanded && (
                    <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="overflow-hidden"
                    >
                        <div className="px-4 py-3 border-t border-border/30 space-y-2">
                            {stage.findings && stage.findings.length > 0 && stage.findings.map((finding, i) => (
                                <div key={i} className="text-xs text-text-dim leading-relaxed bg-background/50 rounded p-3 border border-border/20">
                                    {finding.executive_summary && <p className="text-text mb-2">{finding.executive_summary}</p>}
                                    {finding.findings && finding.findings.map((f, j) => (
                                        <div key={j} className="mt-2 pl-3 border-l-2 border-primary/30">
                                            <div className="flex items-center gap-2 mb-1">
                                                {f.severity && <span className={`text-[9px] font-mono uppercase px-1.5 py-0.5 rounded ${f.severity === 'CRITICAL' || f.severity === 'HIGH' ? 'bg-red-500/15 text-red-400' : 'bg-amber-500/15 text-amber-400'}`}>{f.severity}</span>}
                                                {f.location && <span className="text-[9px] font-mono text-text-dim">{f.location}</span>}
                                            </div>
                                            {f.cobol_behavior && <p className="text-[11px]"><span className="text-text-dim">COBOL:</span> {f.cobol_behavior}</p>}
                                            {f.python_behavior && <p className="text-[11px]"><span className="text-text-dim">Python:</span> {f.python_behavior}</p>}
                                            {f.fix && <p className="text-[11px] text-primary/80"><span className="text-text-dim">Fix:</span> {f.fix}</p>}
                                        </div>
                                    ))}
                                    {finding.verified_findings && finding.verified_findings.map((vf, j) => (
                                        <div key={j} className="mt-2 pl-3 border-l-2 border-green-500/30">
                                            <span className="text-[9px] font-mono text-green-400 uppercase">Verified</span>
                                            <p className="text-[11px] text-text">{vf.original_finding || vf.description}</p>
                                        </div>
                                    ))}
                                    {finding.missed_issues && finding.missed_issues.map((mi, j) => (
                                        <div key={j} className="mt-2 pl-3 border-l-2 border-red-500/30">
                                            <span className={`text-[9px] font-mono uppercase px-1.5 py-0.5 rounded bg-red-500/15 text-red-400`}>{mi.severity || 'ISSUE'}</span>
                                            <p className="text-[11px] text-text mt-1">{mi.description}</p>
                                        </div>
                                    ))}
                                    {finding.base_confidence && (
                                        <div className="mt-2 space-y-1">
                                            <div className="flex justify-between text-[11px]"><span className="text-text-dim">Base Confidence</span><span className="text-text">{finding.base_confidence}</span></div>
                                            {finding.missed_penalty && parseFloat(finding.missed_penalty) > 0 && (
                                                <div className="flex justify-between text-[11px]"><span className="text-text-dim">Missed Issues Penalty</span><span className="text-red-400">-{finding.missed_penalty}</span></div>
                                            )}
                                            {finding.incorrect_penalty && parseFloat(finding.incorrect_penalty) > 0 && (
                                                <div className="flex justify-between text-[11px]"><span className="text-text-dim">Incorrect Findings Penalty</span><span className="text-red-400">-{finding.incorrect_penalty}</span></div>
                                            )}
                                            <div className="flex justify-between text-[11px] font-bold border-t border-border/30 pt-1"><span className="text-text">Final Confidence</span><span className="text-primary">{finding.final_confidence}</span></div>
                                        </div>
                                    )}
                                </div>
                            ))}
                            {stage.warnings && stage.warnings.length > 0 && (
                                <div className="space-y-1">
                                    {stage.warnings.map((w, i) => (
                                        <p key={i} className="text-[11px] text-amber-400/80 flex items-start gap-2">
                                            <AlertTriangle size={12} className="mt-0.5 shrink-0" /> {w}
                                        </p>
                                    ))}
                                </div>
                            )}
                            {stage.errors && stage.errors.length > 0 && (
                                <div className="space-y-1">
                                    {stage.errors.map((e, i) => (
                                        <p key={i} className="text-[11px] text-red-400/80 flex items-start gap-2">
                                            <XCircle size={12} className="mt-0.5 shrink-0" /> {e}
                                        </p>
                                    ))}
                                </div>
                            )}
                            {(!stage.findings || stage.findings.length === 0) && (!stage.warnings || stage.warnings.length === 0) && (!stage.errors || stage.errors.length === 0) && (
                                <p className="text-[11px] text-text-dim/50 italic">No detailed findings for this stage.</p>
                            )}
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

// ── Audit Results Panel ─────────────────────────────────────────────
const AuditResultsPanel = ({ audit }) => {
    const [expandedStage, setExpandedStage] = useState(null);

    if (!audit) return null;

    const confidenceNum = parseFloat(audit.confidence) || 0;
    const confidencePercent = Math.round(confidenceNum >= 1 ? confidenceNum : confidenceNum * 100);
    const passed = audit.passed;

    const ringColor = passed ? 'rgb(34, 197, 94)' : confidencePercent >= 70 ? 'rgb(245, 158, 11)' : 'rgb(239, 68, 68)';

    return (
        <div className={`border overflow-hidden ${passed ? 'border-green-500/30' : 'border-amber-500/30'}`}>
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 bg-surface/40 border-b border-border/30">
                <div className="flex items-center gap-4">
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center ${passed ? 'bg-green-500/15' : 'bg-amber-500/15'}`}>
                        {passed ? <CheckCircle size={20} className="text-green-400" /> : <AlertTriangle size={20} className="text-amber-400" />}
                    </div>
                    <div>
                        <h3 className="text-sm font-mono font-bold tracking-wider text-text uppercase">
                            {passed ? 'Audit Passed' : 'Review Required'}
                        </h3>
                        <p className="text-[10px] text-text-dim">
                            {passed ? 'Translation meets zero-error standards' : 'Translation needs verification before production use'}
                        </p>
                    </div>
                </div>
                {/* Confidence ring */}
                <div className="text-center">
                    <div className="relative w-16 h-16">
                        <svg viewBox="0 0 36 36" className="w-full h-full -rotate-90">
                            <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                                fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="3" />
                            <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                                fill="none" stroke={ringColor} strokeWidth="3"
                                strokeDasharray={`${confidencePercent}, 100`}
                                strokeLinecap="round" />
                        </svg>
                        <span className="absolute inset-0 flex items-center justify-center text-sm font-mono font-bold text-text">
                            {confidencePercent}%
                        </span>
                    </div>
                    <span className="text-[9px] font-mono uppercase tracking-wider text-text-dim">{audit.level}</span>
                </div>
            </div>

            {/* Pipeline Stages */}
            {audit.stages && (
                <div className="px-6 py-4 space-y-2">
                    <h4 className="text-[10px] font-mono uppercase tracking-widest text-text-dim mb-3">Verification Pipeline</h4>
                    <AuditStage number={1} name="Initial Analysis" stage={audit.stages.stage_1}
                        isExpanded={expandedStage === 1} onToggle={() => setExpandedStage(expandedStage === 1 ? null : 1)} />
                    <AuditStage number={2} name="Adversarial Verification" stage={audit.stages.stage_2}
                        isExpanded={expandedStage === 2} onToggle={() => setExpandedStage(expandedStage === 2 ? null : 2)} />
                    <AuditStage number={3} name="Confidence Scoring" stage={audit.stages.stage_3}
                        isExpanded={expandedStage === 3} onToggle={() => setExpandedStage(expandedStage === 3 ? null : 3)} />
                </div>
            )}

            {/* Unresolved items */}
            {audit.unresolved && audit.unresolved.length > 0 && (
                <div className="px-6 py-4 border-t border-border/30 bg-amber-500/[0.03]">
                    <h4 className="text-[10px] font-mono uppercase tracking-widest text-amber-400 mb-3">Requires Human Verification</h4>
                    <div className="space-y-2">
                        {audit.unresolved.map((item, i) => (
                            <div key={i} className="bg-background/50 p-3 border border-border/20">
                                {item.category && <span className="text-[9px] font-mono uppercase px-1.5 py-0.5 rounded bg-surface text-text-dim">{item.category}</span>}
                                {item.description && <p className="text-[11px] text-text mt-1">{item.description}</p>}
                                {item.risk_if_wrong && <p className="text-[10px] text-red-400/70 mt-1">Risk: {item.risk_if_wrong}</p>}
                                {item.recommended_action && <p className="text-[10px] text-primary/70 mt-1">Action: {item.recommended_action}</p>}
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
};

// ── Loading State with Pipeline Stages ──────────────────────────────
const AnalysisLoader = ({ stage }) => {
    const stages = [
        { id: 'extracting', label: 'Extracting COBOL Logic', icon: Cpu },
        { id: 'stage1', label: 'Stage 1: Initial Analysis', icon: BrainCircuit },
        { id: 'stage2', label: 'Stage 2: Adversarial Verification', icon: ShieldCheck },
        { id: 'stage3', label: 'Stage 3: Confidence Scoring', icon: CheckCircle },
    ];
    const currentIndex = stages.findIndex(s => s.id === stage);

    return (
        <div className="flex flex-col items-center justify-center min-h-[80vh] space-y-10">
            <div className="relative">
                <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ duration: 4, repeat: Infinity, ease: "linear" }}
                    className="w-32 h-32 border-2 border-primary/20 border-t-primary rounded-full"
                />
                <Cpu className="absolute inset-0 m-auto text-primary w-10 h-10 animate-pulse" />
            </div>
            <div className="text-center space-y-2">
                <h2 className="text-xl font-mono tracking-widest text-text uppercase">Engine Processing</h2>
                <p className="text-text-dim text-xs font-mono uppercase tracking-wider opacity-60">
                    {stages[currentIndex >= 0 ? currentIndex : 0].label}
                </p>
            </div>
            <div className="flex gap-6">
                {stages.map((s, i) => {
                    const Icon = s.icon;
                    const isActive = i <= currentIndex;
                    const isComplete = i < currentIndex;
                    return (
                        <div key={s.id} className={`flex flex-col items-center gap-2 transition-opacity ${isActive ? 'opacity-100' : 'opacity-25'}`}>
                            <div className={`w-10 h-10 rounded-full flex items-center justify-center ${isComplete ? 'bg-green-500/15 text-green-400' : isActive ? 'bg-primary/15 text-primary' : 'bg-surface text-text-dim'}`}>
                                {isComplete ? <Check size={18} /> : <Icon size={18} />}
                            </div>
                            <span className="text-[9px] font-mono text-text-dim text-center max-w-[80px] uppercase tracking-wider">{s.label}</span>
                        </div>
                    );
                })}
            </div>
        </div>
    );
};

// ── Main Engine Component ───────────────────────────────────────────
const Engine = () => {
    const [inputMode, setInputMode] = useState('paste');
    const [cobolCode, setCobolCode] = useState('');
    const [isProcessing, setIsProcessing] = useState(false);
    const [processingStage, setProcessingStage] = useState('extracting');
    const [result, setResult] = useState(null);
    const [error, setError] = useState(null);
    const [copySuccess, setCopySuccess] = useState(false);
    const [showChat, setShowChat] = useState(false);
    const [isDragOver, setIsDragOver] = useState(false);
    const fileInputRef = useRef(null);
    const lineNumbersRef = useRef(null);
    const textareaRef = useRef(null);

    const lineCount = cobolCode ? cobolCode.split('\n').length : 0;
    const charCount = cobolCode.length;

    const handleScroll = useCallback(() => {
        if (lineNumbersRef.current && textareaRef.current) {
            lineNumbersRef.current.scrollTop = textareaRef.current.scrollTop;
        }
    }, []);

    const handleFileUpload = async (fileOrEvent) => {
        const file = fileOrEvent?.target?.files?.[0] || fileOrEvent;
        if (!file) return;
        if (file.size > MAX_FILE_SIZE) {
            setError('File exceeds 10MB limit');
            return;
        }
        const text = await file.text();
        setCobolCode(text);
        setInputMode('paste');
        setError(null);
    };

    const handleDragOver = (e) => { e.preventDefault(); setIsDragOver(true); };
    const handleDragLeave = () => setIsDragOver(false);
    const handleDrop = (e) => {
        e.preventDefault();
        setIsDragOver(false);
        const file = e.dataTransfer.files[0];
        if (file) handleFileUpload(file);
    };

    const handlePaste = (e) => {
        const text = e.clipboardData.getData('text');
        if (text.length > MAX_PASTE_CHARS) {
            e.preventDefault();
            setError(`Content exceeds ${MAX_PASTE_CHARS.toLocaleString()} character limit`);
        }
    };

    const processLogic = async () => {
        if (!cobolCode.trim()) return;
        setIsProcessing(true);
        setError(null);
        setProcessingStage('extracting');

        // Simulate stage progression for UX feedback
        const stageTimer1 = setTimeout(() => setProcessingStage('stage1'), 3000);
        const stageTimer2 = setTimeout(() => setProcessingStage('stage2'), 8000);
        const stageTimer3 = setTimeout(() => setProcessingStage('stage3'), 14000);

        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/analyze'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    cobol_code: cobolCode,
                    filename: 'vault_entry.cbl',
                })
            });
            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                throw new Error(errData.detail || `Analysis failed (${response.status})`);
            }
            const data = await response.json();
            setResult(data);
        } catch (err) {
            setError(err.message || 'Engine processing failure');
        } finally {
            clearTimeout(stageTimer1);
            clearTimeout(stageTimer2);
            clearTimeout(stageTimer3);
            setIsProcessing(false);
        }
    };

    const copyToClipboard = () => {
        const code = result?.python_implementation || result?.corrected_code;
        if (!code) return;
        navigator.clipboard.writeText(code);
        setCopySuccess(true);
        setTimeout(() => setCopySuccess(false), 2000);
    };

    const handleExportPDF = () => {
        if (!result) return;
        generateForensicPDF({
            filename: 'vault_entry.cbl',
            date: new Date().toLocaleString(),
            analyst: localStorage.getItem('corporate_id') || 'Unknown',
            confidence: result.audit?.level || 'N/A',
            summary: result.executive_summary || '',
            cobolCode: cobolCode,
            pythonCode: result.python_implementation || result.corrected_code || '',
            mathBreakdown: result.mathematical_breakdown || '',
            findings: result.findings || [],
            uncertainties: result.uncertainties || result.audit?.unresolved || [],
            audit: result.audit || null,
        });
    };

    const handleReset = () => {
        setResult(null);
        setError(null);
    };

    // ── Loading State ──
    if (isProcessing) {
        return <AnalysisLoader stage={processingStage} />;
    }

    // ── Error State (network/server errors) ──
    if (error && !result) {
        return (
            <div className="p-8 max-w-[1600px] mx-auto space-y-8">
                <div className="flex justify-between items-end mb-4">
                    <div className="space-y-1">
                        <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">The Engine</h1>
                        <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">Legacy Micro-Logic Modernization</p>
                    </div>
                </div>
                <div className="bg-red-500/5 border border-red-500/30 p-10 space-y-6 text-center">
                    <AlertTriangle className="text-red-400 mx-auto" size={40} />
                    <h2 className="text-lg font-mono font-bold tracking-widest text-red-400 uppercase">Analysis Error</h2>
                    <p className="text-sm text-text-dim leading-relaxed max-w-md mx-auto">{error}</p>
                    <button
                        onClick={handleReset}
                        className="px-8 py-3 border border-border text-[10px] uppercase font-mono tracking-widest text-text-dim hover:text-text hover:border-primary transition-all"
                    >
                        Try Again
                    </button>
                </div>
            </div>
        );
    }

    // ── Main UI ──
    return (
        <div className="p-8 max-w-[1600px] mx-auto space-y-8">
            {/* Header */}
            <div className="flex justify-between items-end mb-4">
                <div className="space-y-1">
                    <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">The Engine</h1>
                    <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">Legacy Micro-Logic Modernization</p>
                </div>
                <div className="flex gap-3 items-center">
                    {result && (
                        <>
                            {result.audit && <AuditBadge audit={result.audit} />}
                            <button
                                onClick={() => setShowChat(true)}
                                className="flex items-center gap-2 px-5 py-2 bg-primary/10 border border-primary/30 text-primary text-[10px] uppercase font-mono tracking-widest hover:bg-primary hover:text-black transition-all"
                            >
                                <MessageSquare size={14} /> Consult
                            </button>
                            <button
                                onClick={handleExportPDF}
                                className="flex items-center gap-2 px-5 py-2 bg-surface border border-border text-[10px] uppercase font-mono tracking-widest hover:border-primary transition-all"
                            >
                                <Download size={14} /> Export PDF
                            </button>
                        </>
                    )}
                </div>
            </div>

            {!result ? (
                /* ── INPUT PHASE ── */
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                    <div className="lg:col-span-2 space-y-4">
                        <div className="bg-surface/40 backdrop-blur-xl border border-border overflow-hidden shadow-2xl">
                            <div className="flex border-b border-border items-center justify-between">
                                <div className="flex">
                                    <button
                                        onClick={() => setInputMode('paste')}
                                        className={`px-8 py-4 text-[10px] uppercase font-mono tracking-[0.2em] transition-all ${inputMode === 'paste' ? 'text-primary bg-primary/5 border-b border-primary' : 'text-text-dim hover:text-text'}`}
                                    >
                                        Paste Logic
                                    </button>
                                    <button
                                        onClick={() => setInputMode('deposit')}
                                        className={`px-8 py-4 text-[10px] uppercase font-mono tracking-[0.2em] transition-all ${inputMode === 'deposit' ? 'text-primary bg-primary/5 border-b border-primary' : 'text-text-dim hover:text-text'}`}
                                    >
                                        Deposit File
                                    </button>
                                </div>
                                <div className="px-6 py-4 text-[9px] font-mono text-primary/50 uppercase tracking-widest">
                                    Zero-Error Audit: Active
                                </div>
                            </div>

                            <div className="h-[600px]">
                                <div className="w-full h-full flex flex-col">
                                    <div className="flex-1 overflow-hidden">
                                        {inputMode === 'paste' ? (
                                            <div className="flex h-full">
                                                <div
                                                    ref={lineNumbersRef}
                                                    className="w-12 flex-shrink-0 bg-surface/30 border-r border-border/30 overflow-hidden select-none py-6 pr-2"
                                                    aria-hidden="true"
                                                >
                                                    {Array.from({ length: Math.max(lineCount, 1) }, (_, i) => (
                                                        <div key={i} className="text-right text-[10px] font-mono text-text-dim/30 leading-relaxed pr-1">
                                                            {i + 1}
                                                        </div>
                                                    ))}
                                                </div>
                                                <textarea
                                                    ref={textareaRef}
                                                    value={cobolCode}
                                                    onChange={(e) => { setCobolCode(e.target.value); setError(null); }}
                                                    onScroll={handleScroll}
                                                    onPaste={handlePaste}
                                                    placeholder="INSERT COBOL SOURCE HERE..."
                                                    className="w-full h-full bg-transparent border-none focus:ring-0 text-primary font-mono text-sm leading-relaxed resize-none placeholder:text-text-dim/20 p-6"
                                                />
                                            </div>
                                        ) : (
                                            <div
                                                onClick={() => fileInputRef.current.click()}
                                                onDragOver={handleDragOver}
                                                onDragLeave={handleDragLeave}
                                                onDrop={handleDrop}
                                                className={`w-full h-full flex flex-col items-center justify-center group cursor-pointer transition-all duration-200 ${
                                                    isDragOver
                                                        ? 'border-4 border-dashed border-primary bg-primary/5 scale-[0.98]'
                                                        : 'border-2 border-dashed border-border m-6 hover:border-primary/50'
                                                }`}
                                            >
                                                <input
                                                    type="file"
                                                    ref={fileInputRef}
                                                    onChange={handleFileUpload}
                                                    accept=".cbl,.cob,.cobol,.txt"
                                                    className="hidden"
                                                />
                                                <CloudUpload size={48} className={`mb-4 transition-colors ${isDragOver ? 'text-primary' : 'text-text-dim group-hover:text-primary'}`} />
                                                <span className="text-xs font-mono tracking-widest text-text-dim group-hover:text-text uppercase">
                                                    {isDragOver ? 'DROP TO UPLOAD' : 'DRAG & DROP SECURE ASSET'}
                                                </span>
                                                <span className="text-[9px] font-mono text-text-dim/40 mt-2 uppercase tracking-wider">
                                                    .cbl .cob .cobol .txt — Max 10MB
                                                </span>
                                            </div>
                                        )}
                                    </div>
                                    {inputMode === 'paste' && (
                                        <div className="flex items-center justify-between px-6 py-2 border-t border-border/30 bg-surface/20">
                                            <span className="text-[9px] font-mono text-text-dim/50 uppercase tracking-wider">
                                                {lineCount} {lineCount === 1 ? 'line' : 'lines'} — {charCount.toLocaleString()} chars
                                            </span>
                                            <span className="text-[9px] font-mono text-text-dim/30 uppercase tracking-wider">COBOL</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Sidebar */}
                    <div className="space-y-4">
                        <div className="bg-surface/40 border border-border p-6 space-y-6">
                            <div className="flex items-center gap-3 text-primary">
                                <BrainCircuit size={18} />
                                <span className="text-[10px] uppercase font-mono tracking-widest">Architectural Context</span>
                            </div>
                            <p className="text-xs text-text-dim leading-relaxed">
                                The Alethia Engine performs multi-pass semantic extraction with mandatory zero-error audit verification. All COBOL variables are humanized into descriptive domain-driven logic.
                            </p>
                            <div className="space-y-3">
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>3-Stage Zero-Error Verification</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>Precision Arithmetic (Decimal)</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>SOC-2 Audit Trail</span>
                                </div>
                            </div>

                            {error && (
                                <div className="bg-red-500/10 border border-red-500/30 p-3 text-[11px] text-red-400">
                                    {error}
                                </div>
                            )}

                            <button
                                onClick={processLogic}
                                disabled={!cobolCode.trim()}
                                className="w-full py-4 bg-primary text-black font-mono font-bold text-xs tracking-[0.2em] hover:bg-white transition-all disabled:opacity-30 flex items-center justify-center gap-2 group"
                            >
                                INITIALIZE TRANSLATION
                                <ChevronRight size={16} className="group-hover:translate-x-1 transition-transform" />
                            </button>
                        </div>
                    </div>
                </div>
            ) : (
                /* ── RESULTS PHASE ── */
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="space-y-6"
                >
                    {/* Audit Results Panel (always shown when audit data exists) */}
                    {result.audit && <AuditResultsPanel audit={result.audit} />}

                    {/* Translation Results */}
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-px bg-border border border-border overflow-hidden shadow-[0_0_50px_rgba(0,0,0,0.5)]">
                        {/* Left: Narrative */}
                        <div className="bg-background p-10 space-y-8">
                            <div className="flex items-center gap-3 border-b border-border pb-6">
                                <FileText className="text-primary" size={20} />
                                <h3 className="text-xs font-mono font-bold tracking-[0.3em] uppercase">Logical Narrative</h3>
                            </div>
                            <div className="space-y-6">
                                <div className="space-y-2">
                                    <label className="text-[10px] text-primary/50 uppercase tracking-[0.2em] font-mono">Domain Analysis</label>
                                    <div className="text-sm text-text leading-relaxed font-light">
                                        {result.executive_summary || 'No summary available.'}
                                    </div>
                                </div>
                                {result.mathematical_breakdown && (
                                    <div className="space-y-4 pt-4">
                                        <label className="text-[10px] text-primary/50 uppercase tracking-[0.2em] font-mono">Mathematical Proofs</label>
                                        <div className="text-xs text-text-dim leading-relaxed bg-surface/30 p-4 border border-border/50">
                                            {result.mathematical_breakdown}
                                        </div>
                                    </div>
                                )}
                            </div>
                            <button
                                onClick={handleReset}
                                className="px-6 py-3 border border-border text-[10px] uppercase font-mono tracking-widest text-text-dim hover:text-text hover:border-primary transition-all"
                            >
                                Reset Engine
                            </button>
                        </div>

                        {/* Right: Code */}
                        <div className="bg-background p-10 relative flex flex-col border-l border-border/50">
                            <div className="flex justify-between items-center border-b border-border/30 pb-6 mb-8">
                                <div className="flex items-center gap-3">
                                    <Code2 className="text-primary" size={20} />
                                    <h3 className="text-xs font-mono font-bold tracking-[0.3em] uppercase">Python 3.12 (A-Vault Spec)</h3>
                                </div>
                                <button
                                    onClick={copyToClipboard}
                                    className="flex items-center gap-2 px-4 py-2 bg-primary/10 text-primary border border-primary/20 text-[10px] uppercase font-mono tracking-widest hover:bg-primary hover:text-black transition-all"
                                >
                                    {copySuccess ? <Check size={14} /> : <Copy size={14} />}
                                    {copySuccess ? 'Copied' : 'Copy Python'}
                                </button>
                            </div>
                            <div className="flex-1 overflow-auto">
                                <div className="bg-surface/30 border border-border/50 p-6 min-h-[300px]">
                                    <pre className="font-mono text-sm leading-7 text-text whitespace-pre-wrap break-words selection:bg-primary/20">
                                        <code>{result.python_implementation || result.corrected_code || 'No translation available.'}</code>
                                    </pre>
                                </div>
                            </div>
                        </div>
                    </div>
                </motion.div>
            )}

            <AnimatePresence>
                {showChat && result && (
                    <ExplanationChat
                        cobolContext={cobolCode}
                        pythonContext={result.python_implementation || result.corrected_code || ''}
                        onClose={() => setShowChat(false)}
                    />
                )}
            </AnimatePresence>
        </div>
    );
};

export default Engine;
