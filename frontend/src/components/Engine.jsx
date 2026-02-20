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
    ShieldCheck,
    Check,
    CloudUpload,
    MessageSquare,
    AlertTriangle,
    CheckCircle,
    XCircle,
    Hash,
    GitBranch,
    FileCode,
    ArrowRight,
    RefreshCw,
    Eye
} from 'lucide-react';
import ExplanationChat from './ExplanationChat';
import { apiUrl } from '../config/api';
import { generateForensicPDF } from '../utils/pdfExport';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const MAX_PASTE_CHARS = 500000;

// ── Collapsible Section ─────────────────────────────────────────────
const Section = ({ title, icon: Icon, count, children, defaultOpen = false, badge }) => {
    const [open, setOpen] = useState(defaultOpen);
    return (
        <div className="border border-border/50 overflow-hidden">
            <button
                onClick={() => setOpen(!open)}
                className="w-full flex items-center gap-3 px-5 py-3 bg-surface/30 hover:bg-surface/50 transition-colors text-left"
            >
                <Icon size={14} className="text-primary shrink-0" />
                <span className="flex-1 text-[11px] font-mono uppercase tracking-wider text-text">
                    {title}
                </span>
                {badge && (
                    <span className="text-[9px] font-mono uppercase px-2 py-0.5 border border-amber-500/30 text-amber-400 bg-amber-500/10">
                        {badge}
                    </span>
                )}
                {count !== undefined && (
                    <span className="text-[10px] font-mono text-primary">{count}</span>
                )}
                <ChevronDown size={14} className={`text-text-dim transition-transform ${open ? 'rotate-180' : ''}`} />
            </button>
            <AnimatePresence>
                {open && (
                    <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="overflow-hidden"
                    >
                        <div className="px-5 py-4 border-t border-border/30 space-y-2">
                            {children}
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

// ── Stat Box ────────────────────────────────────────────────────────
const StatBox = ({ label, value, warn }) => (
    <div className={`flex-1 min-w-[100px] p-3 border ${warn ? 'border-amber-500/30 bg-amber-500/5' : 'border-border/30 bg-surface/20'}`}>
        <div className={`text-lg font-mono font-bold ${warn ? 'text-amber-400' : 'text-text'}`}>{value}</div>
        <div className="text-[9px] font-mono uppercase tracking-wider text-text-dim mt-1">{label}</div>
    </div>
);

// ── Confidence Ring ─────────────────────────────────────────────────
const ConfidenceRing = ({ value, label, size = 64 }) => {
    const pct = Math.round(Number(value) || 0);
    const color = pct >= 90 ? 'rgb(34,197,94)' : pct >= 70 ? 'rgb(245,158,11)' : 'rgb(239,68,68)';
    return (
        <div className="text-center">
            <div className="relative" style={{ width: size, height: size }}>
                <svg viewBox="0 0 36 36" className="w-full h-full -rotate-90">
                    <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                        fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="3" />
                    <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                        fill="none" stroke={color} strokeWidth="3"
                        strokeDasharray={`${pct}, 100`}
                        strokeLinecap="round" />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center text-sm font-mono font-bold text-text">
                    {pct}%
                </span>
            </div>
            <span className="text-[9px] font-mono uppercase tracking-wider text-text-dim">{label}</span>
        </div>
    );
};

// ── Loading State ───────────────────────────────────────────────────
const AnalysisLoader = ({ stage }) => {
    const stages = [
        { id: 'parsing', label: 'ANTLR4 Parsing', icon: Cpu },
        { id: 'generating', label: 'Generating Python', icon: Code2 },
        { id: 'verifying', label: 'GPT Verification', icon: ShieldCheck },
        { id: 'finalizing', label: 'Building Report', icon: CheckCircle },
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
    const [fileName, setFileName] = useState('source.cbl');
    const [isProcessing, setIsProcessing] = useState(false);
    const [processingStage, setProcessingStage] = useState('parsing');
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
        setFileName(file.name || 'source.cbl');
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

    // Group items by paragraph
    const groupByParagraph = (items) => {
        const groups = {};
        for (const item of items) {
            const key = item.paragraph || 'UNKNOWN';
            if (!groups[key]) groups[key] = [];
            groups[key].push(item);
        }
        return groups;
    };

    const processLogic = async () => {
        if (!cobolCode.trim()) return;
        setIsProcessing(true);
        setError(null);
        setProcessingStage('parsing');

        const timer1 = setTimeout(() => setProcessingStage('generating'), 2000);
        const timer2 = setTimeout(() => setProcessingStage('verifying'), 5000);
        const timer3 = setTimeout(() => setProcessingStage('finalizing'), 12000);

        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/engine/analyze'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    cobol_code: cobolCode,
                    filename: fileName,
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
            clearTimeout(timer1);
            clearTimeout(timer2);
            clearTimeout(timer3);
            setIsProcessing(false);
        }
    };

    const copyToClipboard = () => {
        const code = result?.generated_python;
        if (!code) return;
        navigator.clipboard.writeText(code);
        setCopySuccess(true);
        setTimeout(() => setCopySuccess(false), 2000);
    };

    const handleExportPDF = () => {
        if (!result) return;
        const v = result.verification || {};
        const conf = v.confidence || {};
        generateForensicPDF({
            filename: fileName,
            date: new Date().toLocaleString(),
            analyst: localStorage.getItem('corporate_id') || 'Unknown',
            confidence: `Overall: ${conf.overall || 'N/A'}%`,
            summary: v.executive_summary || result.formatted_output || '',
            cobolCode: cobolCode,
            pythonCode: result.generated_python || '',
            mathBreakdown: (v.business_logic || []).map(b => `${b.title}: ${b.formula}`).join('\n'),
            findings: (v.checklist || []).map(c => ({
                ref_id: c.status,
                identified_problem: c.item,
                verification_note: c.note,
            })),
            uncertainties: (v.human_review_items || []).map(h => ({
                category: h.severity,
                description: h.item,
                risk_if_wrong: h.reason,
            })),
            audit: null,
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

    // ── Error State ──
    if (error && !result) {
        return (
            <div className="p-8 max-w-[1600px] mx-auto space-y-8">
                <div className="space-y-1">
                    <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">The Engine</h1>
                    <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">Legacy Micro-Logic Modernization</p>
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

    // ── Derived data for results ──
    const parser = result?.parser_output;
    const verification = result?.verification;
    const confidence = verification?.confidence || {};
    const generatedPython = result?.generated_python;

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
                                    Unified Analysis Pipeline
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
                                <Cpu size={18} />
                                <span className="text-[10px] uppercase font-mono tracking-widest">Architectural Context</span>
                            </div>
                            <p className="text-xs text-text-dim leading-relaxed">
                                The Aletheia Engine performs deterministic ANTLR4 parsing, rule-based Python generation, and GPT-4o verification in a single unified pipeline.
                            </p>
                            <div className="space-y-3">
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>ANTLR4 Deterministic Parse</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>Rule-Based Python Generation</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>GPT-4o Verification Layer</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>Precision Arithmetic (Decimal)</span>
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
                                ANALYZE
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
                    {/* ═══ Layer 1: Executive Summary ═══ */}
                    <div className="border border-border overflow-hidden">
                        <div className="flex items-center justify-between px-6 py-4 bg-surface/40 border-b border-border/30">
                            <div className="flex items-center gap-4">
                                <div className={`w-10 h-10 flex items-center justify-center ${(confidence.overall || 0) >= 90 ? 'bg-green-500/15' : 'bg-amber-500/15'}`}>
                                    {(confidence.overall || 0) >= 90
                                        ? <CheckCircle size={20} className="text-green-400" />
                                        : <AlertTriangle size={20} className="text-amber-400" />
                                    }
                                </div>
                                <div>
                                    <h3 className="text-sm font-mono font-bold tracking-wider text-text uppercase">
                                        {(confidence.overall || 0) >= 95 ? 'Analysis Complete' : 'Review Required'}
                                    </h3>
                                    <p className="text-[10px] text-text-dim">
                                        {parser?.filename || fileName}
                                    </p>
                                </div>
                            </div>
                            <div className="flex gap-6">
                                <ConfidenceRing value={confidence.parser} label="Parser" />
                                <ConfidenceRing value={confidence.translation} label="Translation" />
                                <ConfidenceRing value={confidence.verification} label="Verification" />
                                <ConfidenceRing value={confidence.overall} label="Overall" size={72} />
                            </div>
                        </div>
                        <div className="px-6 py-5">
                            <p className="text-sm text-text leading-relaxed">
                                {verification?.executive_summary || 'No summary available.'}
                            </p>
                        </div>
                    </div>

                    {/* ═══ Layer 2: Business Logic ═══ */}
                    {verification?.business_logic && verification.business_logic.length > 0 && (
                        <Section title="Business Logic" icon={FileText} count={verification.business_logic.length} defaultOpen>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                {verification.business_logic.map((item, i) => (
                                    <div key={i} className="p-4 border border-border/30 bg-background/50 space-y-2">
                                        <h4 className="text-[11px] font-mono font-bold uppercase tracking-wider text-text">{item.title}</h4>
                                        <div className="text-[10px] font-mono text-primary bg-primary/5 px-3 py-2 border border-primary/20">
                                            {item.formula}
                                        </div>
                                        <p className="text-[11px] text-text-dim leading-relaxed">{item.explanation}</p>
                                    </div>
                                ))}
                            </div>
                        </Section>
                    )}

                    {/* ═══ Layer 3: Technical Detail ═══ */}
                    {parser?.success && (
                        <Section title="Technical Detail" icon={Cpu} defaultOpen={false}>
                            {/* Summary Stats */}
                            <div className="flex flex-wrap gap-2 mb-4">
                                <StatBox label="Paragraphs" value={parser.summary?.paragraphs ?? 0} />
                                <StatBox label="Variables" value={parser.summary?.variables ?? 0} />
                                <StatBox label="COMP-3" value={parser.summary?.comp3_variables ?? 0} warn={parser.summary?.comp3_variables > 0} />
                                <StatBox label="PERFORM Calls" value={parser.summary?.perform_calls ?? 0} />
                                <StatBox label="COMPUTE" value={parser.summary?.compute_statements ?? 0} />
                                <StatBox label="Business Rules" value={parser.summary?.business_rules ?? 0} />
                                <StatBox label="Cycles" value={parser.summary?.cycles ?? 0} warn={parser.summary?.cycles > 0} />
                                <StatBox label="Unreachable" value={parser.summary?.unreachable ?? 0} warn={parser.summary?.unreachable > 0} />
                            </div>

                            {/* Paragraphs */}
                            <div className="space-y-1 mb-3">
                                <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pb-1">Paragraphs</div>
                                {parser.paragraphs?.map((name, i) => (
                                    <div key={i} className="flex items-center gap-3 px-3 py-2 bg-background/50 border border-border/20">
                                        <span className={`text-[10px] font-mono ${i === 0 ? 'text-primary font-bold' : 'text-text'}`}>{name}</span>
                                        {i === 0 && (
                                            <span className="text-[8px] font-mono uppercase px-1.5 py-0.5 border border-primary/30 text-primary bg-primary/10">
                                                Entry Point
                                            </span>
                                        )}
                                    </div>
                                ))}
                            </div>

                            {/* Variables */}
                            <div className="space-y-1 mb-3">
                                <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pb-1">
                                    Variables {parser.summary?.comp3_variables > 0 && <span className="text-amber-400 ml-2">{parser.summary.comp3_variables} COMP-3</span>}
                                </div>
                                {parser.variables?.map((v, i) => (
                                    <div key={i} className={`flex items-center gap-3 px-3 py-2 border ${v.comp3 ? 'border-amber-500/30 bg-amber-500/5' : 'border-border/20 bg-background/50'}`}>
                                        <span className={`text-[10px] font-mono flex-1 ${v.comp3 ? 'text-amber-400' : 'text-text-dim'}`}>{v.raw}</span>
                                        {v.comp3 && (
                                            <span className="text-[8px] font-mono uppercase px-1.5 py-0.5 border border-amber-500/30 text-amber-400 bg-amber-500/10 shrink-0">
                                                COMP-3
                                            </span>
                                        )}
                                    </div>
                                ))}
                            </div>

                            {/* Control Flow */}
                            {parser.control_flow?.length > 0 && (
                                <div className="space-y-1 mb-3">
                                    <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pb-1">Control Flow</div>
                                    {parser.control_flow.map((edge, i) => (
                                        <div key={i} className="flex items-center gap-3 px-3 py-2 bg-background/50 border border-border/20">
                                            <span className="text-[10px] font-mono text-primary">{edge.from}</span>
                                            <ArrowRight size={12} className="text-text-dim/40 shrink-0" />
                                            <span className="text-[10px] font-mono text-text">{edge.to}</span>
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* COMPUTE Statements */}
                            {parser.computes?.length > 0 && (
                                <div className="space-y-1 mb-3">
                                    <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pb-1">COMPUTE Statements</div>
                                    {Object.entries(groupByParagraph(parser.computes)).map(([para, items]) => (
                                        <div key={para} className="space-y-1">
                                            <div className="text-[9px] font-mono uppercase tracking-wider text-text-dim/60 pt-1">{para}</div>
                                            {items.map((c, i) => (
                                                <div key={i} className="px-3 py-2 bg-background/50 border border-border/20">
                                                    <span className="text-[10px] font-mono text-text-dim break-all">{c.statement}</span>
                                                </div>
                                            ))}
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* IF Conditions */}
                            {parser.conditions?.length > 0 && (
                                <div className="space-y-1 mb-3">
                                    <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pb-1">Business Rules (IF)</div>
                                    {Object.entries(groupByParagraph(parser.conditions)).map(([para, items]) => (
                                        <div key={para} className="space-y-1">
                                            <div className="text-[9px] font-mono uppercase tracking-wider text-text-dim/60 pt-1">{para}</div>
                                            {items.map((c, i) => (
                                                <div key={i} className="px-3 py-2 bg-background/50 border border-border/20">
                                                    <span className="text-[10px] font-mono text-text-dim break-all">{c.statement}</span>
                                                </div>
                                            ))}
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* Warnings */}
                            {((parser.cycles?.length > 0) || (parser.unreachable?.length > 0)) && (
                                <div className="space-y-2 mt-3">
                                    {parser.cycles?.length > 0 && (
                                        <div className="space-y-1">
                                            <div className="text-[9px] font-mono uppercase tracking-wider text-amber-400">Cycles Detected</div>
                                            {parser.cycles.map((cycle, i) => (
                                                <div key={i} className="flex items-center gap-2 px-3 py-2 border border-amber-500/30 bg-amber-500/5">
                                                    <AlertTriangle size={12} className="text-amber-400 shrink-0" />
                                                    <span className="text-[10px] font-mono text-amber-400">{cycle.join(' \u2192 ')} \u2192 {cycle[0]}</span>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                    {parser.unreachable?.length > 0 && (
                                        <div className="space-y-1">
                                            <div className="text-[9px] font-mono uppercase tracking-wider text-red-400">Unreachable Code</div>
                                            {parser.unreachable.map((name, i) => (
                                                <div key={i} className="flex items-center gap-2 px-3 py-2 border border-red-500/30 bg-red-500/5">
                                                    <XCircle size={12} className="text-red-400 shrink-0" />
                                                    <span className="text-[10px] font-mono text-red-400">{name}</span>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}
                        </Section>
                    )}

                    {/* ═══ Layer 4: Generated Python ═══ */}
                    {generatedPython && (
                        <div className="border border-green-500/30 overflow-hidden">
                            <div className="flex items-center justify-between px-5 py-3 bg-green-500/5 border-b border-green-500/20">
                                <div className="flex items-center gap-3">
                                    <Code2 size={16} className="text-green-400" />
                                    <span className="text-[11px] font-mono uppercase tracking-wider text-text">
                                        Generated Python 3.12
                                    </span>
                                    <span className="text-[9px] font-mono uppercase px-2 py-0.5 border border-green-500/30 text-green-400 bg-green-500/10">
                                        Decimal-Safe
                                    </span>
                                </div>
                                <button
                                    onClick={copyToClipboard}
                                    className="flex items-center gap-2 px-4 py-1.5 bg-primary/10 text-primary border border-primary/20 text-[10px] uppercase font-mono tracking-widest hover:bg-primary hover:text-black transition-all"
                                >
                                    {copySuccess ? <Check size={12} /> : <Copy size={12} />}
                                    {copySuccess ? 'Copied' : 'Copy'}
                                </button>
                            </div>
                            <div className="bg-background/80 overflow-auto max-h-[600px]">
                                <div className="flex">
                                    <div className="w-12 flex-shrink-0 bg-surface/30 border-r border-border/30 select-none py-4 pr-2">
                                        {generatedPython.split('\n').map((_, i) => (
                                            <div key={i} className="text-right text-[10px] font-mono text-text-dim/30 leading-relaxed pr-1">
                                                {i + 1}
                                            </div>
                                        ))}
                                    </div>
                                    <pre className="flex-1 p-4 font-mono text-sm leading-relaxed text-primary whitespace-pre overflow-x-auto">
                                        <code>{generatedPython}</code>
                                    </pre>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ═══ Layer 5: Verification Checklist ═══ */}
                    {verification?.checklist && verification.checklist.length > 0 && (
                        <Section title="Verification Checklist" icon={ShieldCheck} count={verification.checklist.length} defaultOpen>
                            <div className="space-y-1">
                                {verification.checklist.map((item, i) => {
                                    const statusCfg = {
                                        PASS: { color: 'text-green-400 bg-green-500/10 border-green-500/30', Icon: CheckCircle },
                                        FAIL: { color: 'text-red-400 bg-red-500/10 border-red-500/30', Icon: XCircle },
                                        WARN: { color: 'text-amber-400 bg-amber-500/10 border-amber-500/30', Icon: AlertTriangle },
                                    };
                                    const cfg = statusCfg[item.status] || statusCfg.WARN;
                                    const StatusIcon = cfg.Icon;
                                    return (
                                        <div key={i} className="flex items-start gap-3 px-4 py-3 bg-background/50 border border-border/20">
                                            <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 text-[9px] font-mono uppercase tracking-wider border shrink-0 ${cfg.color}`}>
                                                <StatusIcon size={10} />
                                                {item.status}
                                            </span>
                                            <div className="flex-1">
                                                <span className="text-[11px] font-mono text-text">{item.item}</span>
                                                {item.note && <p className="text-[10px] text-text-dim mt-0.5">{item.note}</p>}
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </Section>
                    )}

                    {/* ═══ Layer 6: Human Review Flags ═══ */}
                    {verification?.human_review_items && verification.human_review_items.length > 0 && (
                        <Section title="Human Review Flags" icon={Eye} count={verification.human_review_items.length} defaultOpen>
                            <div className="space-y-2">
                                {verification.human_review_items.map((item, i) => {
                                    const severityCfg = {
                                        HIGH: 'text-red-400 bg-red-500/10 border-red-500/30',
                                        MEDIUM: 'text-amber-400 bg-amber-500/10 border-amber-500/30',
                                        LOW: 'text-text-dim bg-surface/30 border-border/30',
                                    };
                                    const sColor = severityCfg[item.severity] || severityCfg.MEDIUM;
                                    return (
                                        <div key={i} className="p-4 bg-background/50 border border-border/20 space-y-2">
                                            <div className="flex items-center gap-3">
                                                <span className={`text-[9px] font-mono uppercase px-2 py-0.5 border ${sColor}`}>
                                                    {item.severity}
                                                </span>
                                                <span className="text-[11px] font-mono text-text">{item.item}</span>
                                            </div>
                                            {item.reason && (
                                                <p className="text-[10px] text-text-dim pl-1">{item.reason}</p>
                                            )}
                                        </div>
                                    );
                                })}
                            </div>
                        </Section>
                    )}

                    {/* Reset */}
                    <button
                        onClick={handleReset}
                        className="flex items-center gap-2 px-6 py-3 border border-border text-[10px] uppercase font-mono tracking-widest text-text-dim hover:text-text hover:border-primary transition-all"
                    >
                        <RefreshCw size={14} />
                        Reset Engine
                    </button>
                </motion.div>
            )}

            <AnimatePresence>
                {showChat && result && (
                    <ExplanationChat
                        cobolContext={cobolCode}
                        pythonContext={result.generated_python || ''}
                        onClose={() => setShowChat(false)}
                    />
                )}
            </AnimatePresence>
        </div>
    );
};

export default Engine;
