import { useState, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Terminal,
    ChevronDown,
    ChevronRight,
    CloudUpload,
    AlertTriangle,
    CheckCircle,
    XCircle,
    ArrowRight,
    RefreshCw,
    Copy,
    Check,
    GitBranch,
    Hash,
    FileCode,
    ShieldCheck,
    Cpu
} from 'lucide-react';
import { apiUrl } from '../config/api';

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

// ── Main Component ──────────────────────────────────────────────────
const DeterministicEngine = () => {
    const [inputMode, setInputMode] = useState('paste');
    const [cobolCode, setCobolCode] = useState('');
    const [isProcessing, setIsProcessing] = useState(false);
    const [result, setResult] = useState(null);
    const [error, setError] = useState(null);
    const [isDragOver, setIsDragOver] = useState(false);
    const [copySuccess, setCopySuccess] = useState(false);
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

    const parseCobol = async () => {
        if (!cobolCode.trim()) return;
        setIsProcessing(true);
        setError(null);

        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/parse'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    cobol_code: cobolCode,
                    filename: 'source.cbl',
                })
            });
            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                throw new Error(errData.detail || `Parse failed (${response.status})`);
            }
            const data = await response.json();
            if (!data.success) {
                throw new Error(data.message || 'Parse failed with syntax errors');
            }
            setResult(data);
        } catch (err) {
            setError(err.message || 'Parser failure');
        } finally {
            setIsProcessing(false);
        }
    };

    const copySource = () => {
        navigator.clipboard.writeText(cobolCode);
        setCopySuccess(true);
        setTimeout(() => setCopySuccess(false), 2000);
    };

    const handleReset = () => {
        setResult(null);
        setError(null);
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

    // ── Loading State ──
    if (isProcessing) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[80vh] space-y-10">
                <div className="relative">
                    <motion.div
                        animate={{ rotate: 360 }}
                        transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                        className="w-32 h-32 border-2 border-primary/20 border-t-primary rounded-full"
                    />
                    <Terminal className="absolute inset-0 m-auto text-primary w-10 h-10" />
                </div>
                <div className="text-center space-y-2">
                    <h2 className="text-xl font-mono tracking-widest text-text uppercase">ANTLR4 Parsing</h2>
                    <p className="text-text-dim text-xs font-mono uppercase tracking-wider opacity-60">
                        Deterministic analysis — zero GPT
                    </p>
                </div>
            </div>
        );
    }

    // ── Error State ──
    if (error && !result) {
        return (
            <div className="p-8 max-w-[1600px] mx-auto space-y-8">
                <div className="space-y-1">
                    <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">Deterministic Engine</h1>
                    <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">ANTLR4 COBOL Parser</p>
                </div>
                <div className="bg-red-500/5 border border-red-500/30 p-10 space-y-6 text-center">
                    <AlertTriangle className="text-red-400 mx-auto" size={40} />
                    <h2 className="text-lg font-mono font-bold tracking-widest text-red-400 uppercase">Parse Error</h2>
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
                    <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">Deterministic Engine</h1>
                    <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">ANTLR4 COBOL Parser — Real Parsing, Not GPT</p>
                </div>
                <div className="flex gap-3 items-center">
                    {result && (
                        <>
                            <button
                                onClick={copySource}
                                className="flex items-center gap-2 px-5 py-2 bg-surface border border-border text-[10px] uppercase font-mono tracking-widest hover:border-primary transition-all"
                            >
                                {copySuccess ? <Check size={14} /> : <Copy size={14} />}
                                {copySuccess ? 'Copied' : 'Copy Source'}
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
                                    Deterministic Parse Mode
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
                                                    {isDragOver ? 'DROP TO UPLOAD' : 'DRAG & DROP COBOL SOURCE'}
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
                                <Terminal size={18} />
                                <span className="text-[10px] uppercase font-mono tracking-widest">Parser Specification</span>
                            </div>
                            <p className="text-xs text-text-dim leading-relaxed">
                                The Deterministic Engine uses ANTLR4-generated parsers with the official COBOL85 grammar. No GPT. No hallucination. Pure syntax tree traversal.
                            </p>
                            <div className="space-y-3">
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>ANTLR4 Parser — Zero GPT</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>COMP-3 Variable Detection</span>
                                </div>
                                <div className="flex items-center gap-3 text-xs text-text-dim/60">
                                    <ShieldCheck size={14} className="text-primary" />
                                    <span>Cycle & Unreachable Code Analysis</span>
                                </div>
                            </div>

                            {/* Badges */}
                            <div className="space-y-2 pt-2">
                                <div className="flex items-center gap-2 px-3 py-2 border border-green-500/30 bg-green-500/5 text-[9px] font-mono uppercase tracking-widest text-green-400">
                                    <CheckCircle size={12} />
                                    1,000,000 Tests Passed
                                </div>
                                <div className="flex items-center gap-2 px-3 py-2 border border-primary/30 bg-primary/5 text-[9px] font-mono uppercase tracking-widest text-primary">
                                    <Cpu size={12} />
                                    ANTLR4 Parser &bull; Zero GPT
                                </div>
                            </div>

                            {error && (
                                <div className="bg-red-500/10 border border-red-500/30 p-3 text-[11px] text-red-400">
                                    {error}
                                </div>
                            )}

                            <button
                                onClick={parseCobol}
                                disabled={!cobolCode.trim()}
                                className="w-full py-4 bg-primary text-black font-mono font-bold text-xs tracking-[0.2em] hover:bg-white transition-all disabled:opacity-30 flex items-center justify-center gap-2 group"
                            >
                                PARSE COBOL
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
                    {/* Parser badge */}
                    <div className="flex items-center gap-4 mb-2">
                        <div className="inline-flex items-center gap-2 px-3 py-1.5 border border-green-500/30 text-[10px] font-mono uppercase tracking-widest text-green-400 bg-green-500/10">
                            <CheckCircle size={14} />
                            <span>Parse Successful</span>
                        </div>
                        <span className="text-[10px] font-mono text-text-dim uppercase tracking-wider">
                            {result.parser} &bull; {result.filename}
                        </span>
                    </div>

                    {/* Summary Stats */}
                    <div className="flex flex-wrap gap-2">
                        <StatBox label="Paragraphs" value={result.summary?.paragraphs ?? 0} />
                        <StatBox label="Variables" value={result.summary?.variables ?? 0} />
                        <StatBox label="COMP-3" value={result.summary?.comp3_variables ?? 0} warn={result.summary?.comp3_variables > 0} />
                        <StatBox label="PERFORM Calls" value={result.summary?.perform_calls ?? 0} />
                        <StatBox label="COMPUTE" value={result.summary?.compute_statements ?? 0} />
                        <StatBox label="Business Rules" value={result.summary?.business_rules ?? 0} />
                        <StatBox label="Cycles" value={result.summary?.cycles ?? 0} warn={result.summary?.cycles > 0} />
                        <StatBox label="Unreachable" value={result.summary?.unreachable ?? 0} warn={result.summary?.unreachable > 0} />
                    </div>

                    {/* Sections */}
                    <div className="space-y-2">
                        {/* Paragraphs */}
                        <Section title="Paragraphs" icon={FileCode} count={result.paragraphs?.length} defaultOpen>
                            <div className="space-y-1">
                                {result.paragraphs?.map((name, i) => (
                                    <div key={i} className="flex items-center gap-3 px-3 py-2 bg-background/50 border border-border/20">
                                        <span className={`text-[10px] font-mono ${i === 0 ? 'text-primary font-bold' : 'text-text'}`}>
                                            {name}
                                        </span>
                                        {i === 0 && (
                                            <span className="text-[8px] font-mono uppercase px-1.5 py-0.5 border border-primary/30 text-primary bg-primary/10">
                                                Entry Point
                                            </span>
                                        )}
                                    </div>
                                ))}
                                {(!result.paragraphs || result.paragraphs.length === 0) && (
                                    <p className="text-[11px] text-text-dim/50 italic">No paragraphs detected.</p>
                                )}
                            </div>
                        </Section>

                        {/* Variables */}
                        <Section
                            title="Variables"
                            icon={Hash}
                            count={result.variables?.length}
                            badge={result.summary?.comp3_variables > 0 ? `${result.summary.comp3_variables} COMP-3` : undefined}
                        >
                            <div className="space-y-1">
                                {result.variables?.map((v, i) => (
                                    <div key={i} className={`flex items-center gap-3 px-3 py-2 border ${v.comp3 ? 'border-amber-500/30 bg-amber-500/5' : 'border-border/20 bg-background/50'}`}>
                                        <span className={`text-[10px] font-mono flex-1 ${v.comp3 ? 'text-amber-400' : 'text-text-dim'}`}>
                                            {v.raw}
                                        </span>
                                        {v.comp3 && (
                                            <span className="text-[8px] font-mono uppercase px-1.5 py-0.5 border border-amber-500/30 text-amber-400 bg-amber-500/10 shrink-0">
                                                COMP-3
                                            </span>
                                        )}
                                    </div>
                                ))}
                                {(!result.variables || result.variables.length === 0) && (
                                    <p className="text-[11px] text-text-dim/50 italic">No variables detected.</p>
                                )}
                            </div>
                        </Section>

                        {/* Control Flow */}
                        <Section title="Control Flow" icon={GitBranch} count={result.control_flow?.length}>
                            <div className="space-y-1">
                                {result.control_flow?.map((edge, i) => (
                                    <div key={i} className="flex items-center gap-3 px-3 py-2 bg-background/50 border border-border/20">
                                        <span className="text-[10px] font-mono text-primary">{edge.from}</span>
                                        <ArrowRight size={12} className="text-text-dim/40 shrink-0" />
                                        <span className="text-[10px] font-mono text-text">{edge.to}</span>
                                    </div>
                                ))}
                                {(!result.control_flow || result.control_flow.length === 0) && (
                                    <p className="text-[11px] text-text-dim/50 italic">No PERFORM calls detected.</p>
                                )}
                            </div>
                        </Section>

                        {/* COMPUTE Statements */}
                        <Section title="COMPUTE Statements" icon={Cpu} count={result.computes?.length}>
                            {Object.entries(groupByParagraph(result.computes || [])).map(([para, items]) => (
                                <div key={para} className="space-y-1">
                                    <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pt-2">{para}</div>
                                    {items.map((c, i) => (
                                        <div key={i} className="px-3 py-2 bg-background/50 border border-border/20">
                                            <span className="text-[10px] font-mono text-text-dim break-all">{c.statement}</span>
                                        </div>
                                    ))}
                                </div>
                            ))}
                            {(!result.computes || result.computes.length === 0) && (
                                <p className="text-[11px] text-text-dim/50 italic">No COMPUTE statements detected.</p>
                            )}
                        </Section>

                        {/* IF Conditions */}
                        <Section title="Business Rules (IF)" icon={ShieldCheck} count={result.conditions?.length}>
                            {Object.entries(groupByParagraph(result.conditions || [])).map(([para, items]) => (
                                <div key={para} className="space-y-1">
                                    <div className="text-[9px] font-mono uppercase tracking-wider text-primary/60 pt-2">{para}</div>
                                    {items.map((c, i) => (
                                        <div key={i} className="px-3 py-2 bg-background/50 border border-border/20">
                                            <span className="text-[10px] font-mono text-text-dim break-all">{c.statement}</span>
                                        </div>
                                    ))}
                                </div>
                            ))}
                            {(!result.conditions || result.conditions.length === 0) && (
                                <p className="text-[11px] text-text-dim/50 italic">No IF conditions detected.</p>
                            )}
                        </Section>

                        {/* Warnings: Cycles + Unreachable */}
                        {((result.cycles && result.cycles.length > 0) || (result.unreachable && result.unreachable.length > 0)) && (
                            <Section title="Warnings" icon={AlertTriangle} defaultOpen>
                                {result.cycles?.length > 0 && (
                                    <div className="space-y-2">
                                        <div className="text-[9px] font-mono uppercase tracking-wider text-amber-400">Cycles Detected</div>
                                        {result.cycles.map((cycle, i) => (
                                            <div key={i} className="flex items-center gap-2 px-3 py-2 border border-amber-500/30 bg-amber-500/5">
                                                <AlertTriangle size={12} className="text-amber-400 shrink-0" />
                                                <span className="text-[10px] font-mono text-amber-400">
                                                    {cycle.join(' → ')} → {cycle[0]}
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                )}
                                {result.unreachable?.length > 0 && (
                                    <div className="space-y-2 mt-3">
                                        <div className="text-[9px] font-mono uppercase tracking-wider text-red-400">Unreachable Code</div>
                                        {result.unreachable.map((name, i) => (
                                            <div key={i} className="flex items-center gap-2 px-3 py-2 border border-red-500/30 bg-red-500/5">
                                                <XCircle size={12} className="text-red-400 shrink-0" />
                                                <span className="text-[10px] font-mono text-red-400">{name}</span>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </Section>
                        )}
                    </div>

                    {/* Reset */}
                    <button
                        onClick={handleReset}
                        className="flex items-center gap-2 px-6 py-3 border border-border text-[10px] uppercase font-mono tracking-widest text-text-dim hover:text-text hover:border-primary transition-all"
                    >
                        <RefreshCw size={14} />
                        Reset Parser
                    </button>
                </motion.div>
            )}
        </div>
    );
};

export default DeterministicEngine;
