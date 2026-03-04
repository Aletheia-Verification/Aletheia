import { useState, useRef, useCallback } from 'react';
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
    Eye,
    Search,
    Settings,
    Database
} from 'lucide-react';
import ExplanationChat from './ExplanationChat';
import { apiUrl } from '../config/api';
import { generateForensicPDF } from '../utils/pdfExport';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const MAX_PASTE_CHARS = 500000;

// ── Colors ──────────────────────────────────────────────────────────
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

// ── Collapsible Section ─────────────────────────────────────────────
const Section = ({ title, icon: Icon, count, children, defaultOpen = false, badge }) => {
    const [open, setOpen] = useState(defaultOpen);
    return (
        <div className="border-b" style={{ borderColor: C.border }}>
            <button
                onClick={() => setOpen(!open)}
                className="w-full flex items-center gap-4 px-0 py-6 text-left group"
            >
                <Icon size={16} strokeWidth={1.5} style={{ color: C.faint }} className="shrink-0" />
                <span className="flex-1 text-[14px] font-semibold uppercase tracking-[0.15em] pb-0" style={{ color: C.navy }}>
                    {title}
                </span>
                {badge && (
                    <span className="text-[9px] font-semibold uppercase px-2.5 py-1 tracking-wider rounded-sm" style={{
                        color: badge === 'CRITICAL' ? C.red : badge === 'WARN' ? C.amber : C.navy,
                        backgroundColor: badge === 'CRITICAL' ? C.redBg : badge === 'WARN' ? C.amberBg : C.bgAlt,
                        border: `1px solid ${badge === 'CRITICAL' ? C.redBorder : badge === 'WARN' ? C.amberBorder : C.border}`,
                    }}>
                        {badge}
                    </span>
                )}
                {count !== undefined && (
                    <span className="text-[11px]" style={{ color: C.faint }}>{count}</span>
                )}
                <ChevronDown size={16} style={{ color: C.faint }} className={`transition-transform duration-200 ${open ? 'rotate-180' : ''}`} />
            </button>
            <div className="collapse-panel" data-open={open}>
                <div className="pb-8">
                    {children}
                </div>
            </div>
        </div>
    );
};

// ── Loading State ───────────────────────────────────────────────────
const AnalysisLoader = ({ stage }) => {
    const stages = [
        { id: 'parsing', label: 'ANTLR4 Parsing', icon: Cpu },
        { id: 'generating', label: 'Generating Python', icon: Code2 },
        { id: 'verifying', label: 'Verification', icon: ShieldCheck },
        { id: 'finalizing', label: 'Building Report', icon: CheckCircle },
    ];
    const currentIndex = stages.findIndex(s => s.id === stage);

    return (
        <div className="flex flex-col items-center justify-center min-h-[80vh] space-y-12 bg-white">
            <div className="relative">
                <div
                    className="w-20 h-20 border border-[#E5E7EB] border-t-[#1B2A4A] animate-spin"
                    style={{ borderRadius: '50%', animationDuration: '3s' }}
                />
                <Cpu className="absolute inset-0 m-auto w-7 h-7 animate-pulse" style={{ color: C.navy }} strokeWidth={1.5} />
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
    const [showCode, setShowCode] = useState(false);
    const [varFilter, setVarFilter] = useState('');
    const [truncMode, setTruncMode] = useState('STD');
    const [showCompiler, setShowCompiler] = useState(false);
    const [multiFiles, setMultiFiles] = useState([]);
    const [depResult, setDepResult] = useState(null);
    const fileInputRef = useRef(null);
    const multiFileInputRef = useRef(null);
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
        console.log('[Engine] File upload - name:', file.name, 'size:', file.size);
        if (file.size > MAX_FILE_SIZE) {
            setError('File exceeds 10MB limit');
            return;
        }
        const text = await file.text();
        console.log('[Engine] File text length:', text.length);
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

    const handleMultiFileUpload = async (e) => {
        const files = Array.from(e.target.files || []);
        const newFiles = [];
        for (const file of files) {
            if (file.size > MAX_FILE_SIZE) continue;
            const text = await file.text();
            newFiles.push({ name: file.name, code: text });
        }
        setMultiFiles(prev => [...prev, ...newFiles]);
        setError(null);
    };

    const removeMultiFile = (index) => {
        setMultiFiles(prev => prev.filter((_, i) => i !== index));
    };

    const [expandedPrograms, setExpandedPrograms] = useState(new Set());

    const toggleProgramCode = (progName) => {
        setExpandedPrograms(prev => {
            const next = new Set(prev);
            if (next.has(progName)) next.delete(progName);
            else next.add(progName);
            return next;
        });
    };

    const processMultiProgram = async () => {
        if (multiFiles.length === 0) return;
        setIsProcessing(true);
        setError(null);
        setProcessingStage('parsing');

        const timer1 = setTimeout(() => setProcessingStage('generating'), 2000);
        const timer2 = setTimeout(() => setProcessingStage('verifying'), 5000);
        const timer3 = setTimeout(() => setProcessingStage('finalizing'), 12000);

        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/engine/analyze-batch'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({
                    programs: multiFiles.map(f => ({
                        filename: f.name,
                        cobol_code: f.code,
                    })),
                    compiler_config: { trunc_mode: truncMode },
                }),
            });
            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                throw new Error(errData.detail || `Batch analysis failed (${response.status})`);
            }
            const data = await response.json();
            setDepResult(data);
        } catch (err) {
            setError(err.message || 'Multi-program analysis failure');
        } finally {
            clearTimeout(timer1);
            clearTimeout(timer2);
            clearTimeout(timer3);
            setIsProcessing(false);
        }
    };

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
                    compiler_config: { trunc_mode: truncMode },
                })
            });
            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                throw new Error(errData.detail || `Analysis failed (${response.status})`);
            }
            const data = await response.json();
            console.log('[Engine] API response:', data);
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

    const handleExportPDF = (mode) => {
        if (!result) return;
        generateForensicPDF(result, cobolCode, fileName, mode);
    };

    const handleReset = () => {
        setResult(null);
        setDepResult(null);
        setError(null);
        setShowCode(false);
        setVarFilter('');
        setExpandedPrograms(new Set());
    };

    // ── Loading State ──
    if (isProcessing) {
        return <AnalysisLoader stage={processingStage} />;
    }

    // ── Error State ──
    if (error && !result) {
        return (
            <div className="p-12 max-w-[1200px] mx-auto space-y-10 bg-white min-h-screen">
                <div className="space-y-1">
                    <h1 className="text-lg font-medium tracking-[0.2em] uppercase" style={{ color: C.text }}>The Engine</h1>
                    <p className="text-[10px] tracking-[0.2em] uppercase" style={{ color: C.faint }}>Deterministic Verification</p>
                </div>
                <div className="p-14 space-y-6 text-center border" style={{ borderColor: C.redBorder, backgroundColor: C.redBg }}>
                    <AlertTriangle style={{ color: C.red }} className="mx-auto" size={32} strokeWidth={1.5} />
                    <h2 className="text-base font-semibold tracking-[0.12em] uppercase" style={{ color: C.red }}>Analysis Error</h2>
                    <p className="text-sm leading-relaxed max-w-md mx-auto" style={{ color: C.body }}>{error}</p>
                    <button
                        onClick={handleReset}
                        className="px-10 py-3 border text-[10px] uppercase tracking-[0.15em] transition-all duration-200 hover:opacity-80"
                        style={{ borderColor: C.border, color: C.muted }}
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
    const generatedPython = result?.generated_python;
    const isVerified = verification?.verification_status === 'VERIFIED';

    // ── Main UI ──
    return (
        <div className="p-12 max-w-[1200px] mx-auto bg-white min-h-screen">
            {/* Header */}
            <div className="flex justify-between items-end mb-10">
                <div className="space-y-1">
                    <h1 className="text-lg font-medium tracking-[0.2em] uppercase" style={{ color: C.text }}>The Engine</h1>
                    <p className="text-[10px] tracking-[0.2em] uppercase" style={{ color: C.faint }}>Deterministic Verification</p>
                </div>
                <div className="flex gap-3 items-center">
                    {result && (
                        <>
                            <button
                                onClick={() => handleExportPDF('executive')}
                                className="flex items-center gap-2 px-5 py-2.5 text-[10px] uppercase tracking-[0.12em] text-white transition-all duration-200 hover:opacity-90 rounded-sm"
                                style={{ backgroundColor: C.navy }}
                            >
                                <Download size={13} strokeWidth={1.5} /> PDF (Executive)
                            </button>
                            <button
                                onClick={() => handleExportPDF('engineer')}
                                className="flex items-center gap-2 px-5 py-2.5 text-[10px] uppercase tracking-[0.12em] text-white transition-all duration-200 hover:opacity-90 rounded-sm"
                                style={{ backgroundColor: C.navy }}
                            >
                                <Download size={13} strokeWidth={1.5} /> PDF (Engineer)
                            </button>
                            <button
                                onClick={() => setShowChat(true)}
                                className="flex items-center gap-2 px-5 py-2.5 border text-[10px] uppercase tracking-[0.12em] transition-all duration-200 hover:opacity-80 rounded-sm"
                                style={{ borderColor: C.border, color: C.muted }}
                            >
                                <MessageSquare size={13} strokeWidth={1.5} /> Consult
                            </button>
                        </>
                    )}
                </div>
            </div>

            {(!result && !depResult) ? (
                /* ── INPUT PHASE ── */
                <>
                {/* ── COMPILER SETTINGS ── */}
                <div className="mb-4" style={{ borderBottom: `1px solid ${C.border}` }}>
                    <button
                        onClick={() => setShowCompiler(!showCompiler)}
                        className="w-full flex items-center gap-3 py-3 text-left"
                    >
                        <Settings size={14} strokeWidth={1.5} style={{ color: C.faint }} />
                        <span className="text-[11px] font-semibold uppercase tracking-[0.15em]" style={{ color: C.muted }}>
                            Compiler Settings
                        </span>
                        <span
                            className="text-[9px] font-mono font-semibold uppercase px-2 py-0.5 tracking-wider ml-auto"
                            style={{ background: C.bgAlt, color: C.navy, border: `1px solid ${C.border}` }}
                        >
                            TRUNC({truncMode})
                        </span>
                        <ChevronDown
                            size={14}
                            strokeWidth={1.5}
                            style={{ color: C.faint, transition: 'transform 200ms', transform: showCompiler ? 'rotate(180deg)' : 'none' }}
                        />
                    </button>
                    {showCompiler && (
                        <div className="pb-4 flex gap-8 items-start fade-in">
                            <div>
                                <label
                                    className="block text-[10px] font-semibold uppercase tracking-[0.12em] mb-1.5"
                                    style={{ color: C.faint }}
                                >
                                    TRUNC Mode
                                </label>
                                <select
                                    value={truncMode}
                                    onChange={(e) => setTruncMode(e.target.value)}
                                    className="text-[12px] font-mono border px-3 py-1.5 bg-white appearance-none cursor-pointer"
                                    style={{ borderColor: C.border, color: C.text, minWidth: 260 }}
                                >
                                    <option value="STD">STD — Standard COBOL truncation</option>
                                    <option value="BIN">BIN — Binary (COMP full range)</option>
                                    <option value="OPT">OPT — Optimized (no truncation)</option>
                                </select>
                            </div>
                            <p className="text-[10px] mt-5 leading-relaxed" style={{ color: C.faint, maxWidth: 280 }}>
                                Match your z/OS compiler settings. TRUNC(STD) is default for most US bank installations.
                            </p>
                        </div>
                    )}
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
                    <div className="lg:col-span-2">
                        <div className="border overflow-hidden rounded-sm" style={{ borderColor: C.border, boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
                            <div className="flex border-b items-center justify-between" style={{ borderColor: C.border }}>
                                <div className="flex">
                                    <button
                                        onClick={() => setInputMode('paste')}
                                        className={`px-8 py-3.5 text-[10px] uppercase tracking-[0.15em] transition-all duration-200 ${
                                            inputMode === 'paste'
                                                ? 'border-b-2'
                                                : ''
                                        }`}
                                        style={{
                                            color: inputMode === 'paste' ? C.navy : C.faint,
                                            borderColor: inputMode === 'paste' ? C.navy : 'transparent',
                                        }}
                                    >
                                        Paste Logic
                                    </button>
                                    <button
                                        onClick={() => setInputMode('deposit')}
                                        className={`px-8 py-3.5 text-[10px] uppercase tracking-[0.15em] transition-all duration-200 ${
                                            inputMode === 'deposit'
                                                ? 'border-b-2'
                                                : ''
                                        }`}
                                        style={{
                                            color: inputMode === 'deposit' ? C.navy : C.faint,
                                            borderColor: inputMode === 'deposit' ? C.navy : 'transparent',
                                        }}
                                    >
                                        Deposit File
                                    </button>
                                    <button
                                        onClick={() => setInputMode('multi')}
                                        className={`px-8 py-3.5 text-[10px] uppercase tracking-[0.15em] transition-all duration-200 ${
                                            inputMode === 'multi'
                                                ? 'border-b-2'
                                                : ''
                                        }`}
                                        style={{
                                            color: inputMode === 'multi' ? C.navy : C.faint,
                                            borderColor: inputMode === 'multi' ? C.navy : 'transparent',
                                        }}
                                    >
                                        Multi-Program
                                    </button>
                                </div>
                            </div>

                            <div className="h-[600px]">
                                <div className="w-full h-full flex flex-col">
                                    <div className="flex-1 overflow-hidden">
                                        {inputMode === 'paste' && (
                                            <div className="flex h-full">
                                                <div
                                                    ref={lineNumbersRef}
                                                    className="w-12 flex-shrink-0 border-r overflow-hidden select-none py-6 pr-2"
                                                    style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}
                                                    aria-hidden="true"
                                                >
                                                    {Array.from({ length: Math.max(lineCount, 1) }, (_, i) => (
                                                        <div key={i} className="text-right text-[10px] font-mono leading-relaxed pr-1" style={{ color: '#D1D5DB' }}>
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
                                                    className="w-full h-full bg-white border-none focus:ring-0 font-mono text-sm leading-relaxed resize-none p-6"
                                                    style={{ color: C.text, '::placeholder': { color: '#D1D5DB' } }}
                                                />
                                            </div>
                                        )}
                                        {inputMode === 'deposit' && (
                                            <div
                                                onClick={() => fileInputRef.current.click()}
                                                onDragOver={handleDragOver}
                                                onDragLeave={handleDragLeave}
                                                onDrop={handleDrop}
                                                className={`w-full h-full flex flex-col items-center justify-center group cursor-pointer transition-all duration-200 ${
                                                    isDragOver ? 'scale-[0.99]' : ''
                                                }`}
                                                style={{
                                                    border: isDragOver ? `3px dashed ${C.navy}` : `2px dashed ${C.border}`,
                                                    backgroundColor: isDragOver ? '#F0F4FF' : 'transparent',
                                                    margin: isDragOver ? 0 : 24,
                                                }}
                                            >
                                                <input
                                                    type="file"
                                                    ref={fileInputRef}
                                                    onChange={handleFileUpload}
                                                    accept=".cbl,.cob,.cobol,.txt"
                                                    className="hidden"
                                                />
                                                <CloudUpload size={36} strokeWidth={1.5} className="mb-4 transition-colors" style={{ color: isDragOver ? C.navy : '#D1D5DB' }} />
                                                <span className="text-xs tracking-[0.12em] uppercase" style={{ color: isDragOver ? C.navy : C.faint }}>
                                                    {isDragOver ? 'DROP TO UPLOAD' : 'DRAG & DROP'}
                                                </span>
                                                <span className="text-[9px] mt-2 uppercase tracking-wider" style={{ color: '#D1D5DB' }}>
                                                    .cbl .cob .cobol .txt — Max 10MB
                                                </span>
                                            </div>
                                        )}
                                        {inputMode === 'multi' && (
                                            <div className="h-full flex flex-col p-6">
                                                <input
                                                    type="file"
                                                    ref={multiFileInputRef}
                                                    onChange={handleMultiFileUpload}
                                                    accept=".cbl,.cob,.cobol,.txt"
                                                    multiple
                                                    className="hidden"
                                                />
                                                <div className="flex items-center justify-between mb-4">
                                                    <span className="text-[10px] uppercase tracking-[0.15em] font-semibold" style={{ color: C.navy }}>
                                                        Program Files ({multiFiles.length})
                                                    </span>
                                                    <button
                                                        onClick={() => multiFileInputRef.current.click()}
                                                        className="px-4 py-2 text-[10px] uppercase tracking-wider border"
                                                        style={{ borderColor: C.navy, color: C.navy }}
                                                    >
                                                        Add Files
                                                    </button>
                                                </div>
                                                <div className="flex-1 overflow-y-auto space-y-2">
                                                    {multiFiles.length === 0 ? (
                                                        <div className="h-full flex flex-col items-center justify-center" style={{ color: '#D1D5DB' }}>
                                                            <GitBranch size={36} strokeWidth={1.5} className="mb-4" />
                                                            <span className="text-xs tracking-[0.12em] uppercase">
                                                                Add multiple COBOL files
                                                            </span>
                                                            <span className="text-[9px] mt-2 uppercase tracking-wider">
                                                                Programs that CALL each other
                                                            </span>
                                                        </div>
                                                    ) : (
                                                        multiFiles.map((f, i) => (
                                                            <div key={i} className="flex items-center justify-between px-4 py-3 border" style={{ borderColor: C.borderLight }}>
                                                                <div className="flex items-center gap-3">
                                                                    <FileCode size={14} strokeWidth={1.5} style={{ color: C.faint }} />
                                                                    <span className="text-[12px] font-mono" style={{ color: C.text }}>{f.name}</span>
                                                                    <span className="text-[9px] font-mono" style={{ color: '#D1D5DB' }}>
                                                                        {f.code.split('\n').length} lines
                                                                    </span>
                                                                </div>
                                                                <button
                                                                    onClick={() => removeMultiFile(i)}
                                                                    className="text-[10px] uppercase tracking-wider px-2 py-1"
                                                                    style={{ color: C.red }}
                                                                >
                                                                    <XCircle size={14} strokeWidth={1.5} />
                                                                </button>
                                                            </div>
                                                        ))
                                                    )}
                                                </div>
                                            </div>
                                        )}
                                    </div>
                                    {inputMode === 'paste' && (
                                        <div className="flex items-center justify-between px-6 py-2 border-t" style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}>
                                            <span className="text-[9px] font-mono uppercase tracking-wider" style={{ color: '#D1D5DB' }}>
                                                {lineCount} {lineCount === 1 ? 'line' : 'lines'} — {charCount.toLocaleString()} chars
                                            </span>
                                            <span className="text-[9px] font-mono uppercase tracking-wider" style={{ color: '#D1D5DB' }}>COBOL</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Sidebar */}
                    <div>
                        <div className="border p-8 space-y-6 rounded-sm" style={{ borderColor: C.border, boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>
                            <div className="flex items-center gap-3">
                                <Cpu size={16} strokeWidth={1.5} style={{ color: C.faint }} />
                                <span className="text-[11px] uppercase tracking-[0.12em]" style={{ color: C.muted }}>Pipeline</span>
                            </div>
                            <p className="text-xs leading-relaxed" style={{ color: C.muted }}>
                                Deterministic ANTLR4 parsing, rule-based Python generation, and automated verification in a single pipeline.
                            </p>
                            <div className="space-y-2.5">
                                {['ANTLR4 Deterministic Parse', 'Rule-Based Python Generation', 'Behavioral Verification', 'Precision Arithmetic (Decimal)'].map((label) => (
                                    <div key={label} className="flex items-center gap-3 text-xs" style={{ color: C.muted }}>
                                        <div className="w-1 h-1 rounded-full" style={{ backgroundColor: C.navy }} />
                                        <span>{label}</span>
                                    </div>
                                ))}
                            </div>

                            {error && (
                                <div className="p-3 text-[11px] border rounded-sm" style={{ borderColor: C.redBorder, backgroundColor: C.redBg, color: C.red }}>
                                    {error}
                                </div>
                            )}

                            <button
                                onClick={inputMode === 'multi' ? processMultiProgram : processLogic}
                                disabled={inputMode === 'multi' ? multiFiles.length === 0 : !cobolCode.trim()}
                                className="w-full py-3.5 text-white font-medium text-xs tracking-[0.15em] uppercase transition-all duration-200 disabled:opacity-25 flex items-center justify-center gap-2 group rounded-sm"
                                style={{ backgroundColor: C.navy }}
                            >
                                {inputMode === 'multi' ? `ANALYZE ALL (${multiFiles.length})` : 'ANALYZE'}
                                <ChevronRight size={14} className="group-hover:translate-x-0.5 transition-transform" />
                            </button>
                        </div>
                    </div>
                </div>
                </>
            ) : (
                /* ── RESULTS PHASE ── */
                <div className="space-y-0 fade-in">
                    {/* ═══ HERO: Verification Status ═══ */}
                    <div className="mb-10 pb-10 pt-12 border-b" style={{ borderColor: C.border }}>
                        <div className="flex items-center justify-between mb-8">
                            <div className="flex items-center gap-5">
                                <div className="w-14 h-14 flex items-center justify-center" style={{
                                    backgroundColor: isVerified ? C.greenBg : C.amberBg,
                                }}>
                                    {isVerified
                                        ? <CheckCircle size={28} strokeWidth={1.5} style={{ color: C.green }} />
                                        : <AlertTriangle size={28} strokeWidth={1.5} style={{ color: C.amber }} />
                                    }
                                </div>
                                <div>
                                    <h2 className="text-xl font-semibold tracking-[0.08em] uppercase" style={{ color: C.text }}>
                                        {isVerified ? 'Verified' : 'Requires Manual Review'}
                                    </h2>
                                    <p className="text-[11px] mt-1 tracking-wide" style={{ color: C.faint }}>
                                        {parser?.filename || fileName}
                                    </p>
                                </div>
                            </div>

                            {/* Hero Badge */}
                            <div className="px-8 py-3.5 text-base font-bold uppercase tracking-widest" style={{
                                backgroundColor: isVerified ? C.navy : C.bg,
                                color: isVerified ? '#FFFFFF' : C.amber,
                                border: isVerified ? 'none' : `2px solid ${C.amberBorder}`,
                            }}>
                                {isVerified ? 'VERIFIED' : 'MANUAL REVIEW'}
                            </div>
                        </div>

                        {/* Key Stats Row */}
                        {parser?.success && (
                            <div className="flex items-center gap-6 text-[12px]" style={{ color: C.muted }}>
                                <span><strong style={{ color: C.text }}>{parser.summary?.paragraphs ?? 0}</strong> Paragraphs</span>
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: C.text }}>{parser.summary?.variables ?? 0}</strong> Variables</span>
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: parser.summary?.comp3_variables > 0 ? C.amber : C.text }}>{parser.summary?.comp3_variables ?? 0}</strong> COMP-3</span>
                                {generatedPython && (
                                    <>
                                        <span style={{ color: C.border }}>|</span>
                                        <span><strong style={{ color: C.text }}>{generatedPython.length.toLocaleString()}</strong> chars Python</span>
                                    </>
                                )}
                            </div>
                        )}
                    </div>

                    {/* ═══ Executive Summary ═══ */}
                    {verification?.executive_summary && (
                        <div className="mb-12 p-8 border-l-[3px]" style={{ borderColor: C.navy, backgroundColor: '#FAFBFC' }}>
                            <p className="text-[16px] leading-[1.8] max-w-[900px]" style={{ color: C.body }}>
                                {verification.executive_summary}
                            </p>
                        </div>
                    )}

                    {/* ═══ Business Logic ═══ */}
                    {verification?.business_logic && verification.business_logic.length > 0 && (
                        <Section title="Business Logic" icon={FileText} count={verification.business_logic.length} defaultOpen>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                                {verification.business_logic.map((item, i) => (
                                    <div key={i} className="p-6 border space-y-4 transition-shadow duration-150 hover:shadow-md" style={{ borderColor: C.border, borderLeftWidth: 3, borderLeftColor: C.navy }}>
                                        <h4 className="text-base font-bold uppercase tracking-[0.08em]" style={{ color: C.text }}>{item.title}</h4>
                                        <div className="text-[12px] font-mono px-4 py-3" style={{ backgroundColor: '#F5F6F8', color: C.navy }}>
                                            {item.formula}
                                        </div>
                                        <p className="text-[12px] leading-relaxed" style={{ color: C.muted }}>{item.explanation}</p>
                                    </div>
                                ))}
                            </div>
                        </Section>
                    )}

                    {/* ═══ Technical Detail ═══ */}
                    {parser?.success && (
                        <Section
                            title="Technical Detail"
                            icon={Cpu}
                            defaultOpen={false}
                        >
                            {/* Summary Stats */}
                            <div className="grid grid-cols-4 gap-3 mb-8">
                                {[
                                    { label: 'Paragraphs', value: parser.summary?.paragraphs ?? 0 },
                                    { label: 'Variables', value: parser.summary?.variables ?? 0 },
                                    { label: 'COMP-3', value: parser.summary?.comp3_variables ?? 0, warn: parser.summary?.comp3_variables > 0 },
                                    { label: 'PERFORM', value: parser.summary?.perform_calls ?? 0 },
                                    { label: 'COMPUTE', value: parser.summary?.compute_statements ?? 0 },
                                    { label: 'Business Rules', value: parser.summary?.business_rules ?? 0 },
                                    { label: 'Cycles', value: parser.summary?.cycles ?? 0, warn: parser.summary?.cycles > 0 },
                                    { label: 'Unreachable', value: parser.summary?.unreachable ?? 0, warn: parser.summary?.unreachable > 0 },
                                ].map((stat) => (
                                    <div key={stat.label} className="p-4 border rounded-sm" style={{
                                        borderColor: stat.warn ? C.amberBorder : C.border,
                                        backgroundColor: stat.warn ? C.amberBg : C.bg,
                                    }}>
                                        <div className="text-xl font-mono font-bold" style={{ color: stat.warn ? C.amber : C.text }}>{stat.value}</div>
                                        <div className="text-[9px] uppercase tracking-[0.12em] mt-1" style={{ color: C.faint }}>{stat.label}</div>
                                    </div>
                                ))}
                            </div>

                            {/* Paragraphs */}
                            <div className="mb-6">
                                <div className="text-[10px] uppercase tracking-[0.12em] mb-3" style={{ color: C.faint }}>Paragraphs</div>
                                <div className="space-y-1">
                                    {parser.paragraphs?.map((name, i) => (
                                        <div key={i} className="flex items-center gap-4 px-4 py-2.5 border rounded-sm" style={{ borderColor: C.borderLight, backgroundColor: i % 2 === 0 ? C.bg : C.bgAlt }}>
                                            <span className="text-[11px] font-mono" style={{ color: i === 0 ? C.navy : C.body, fontWeight: i === 0 ? 600 : 400 }}>{name}</span>
                                            {i === 0 && (
                                                <span className="text-[8px] uppercase px-2 py-0.5 rounded-sm tracking-wider font-medium" style={{ backgroundColor: '#EFF6FF', color: C.navy, border: `1px solid #BFDBFE` }}>
                                                    Entry Point
                                                </span>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Variables Table */}
                            <div className="mb-6">
                                <div className="flex items-center justify-between mb-3">
                                    <div className="text-[10px] uppercase tracking-[0.12em]" style={{ color: C.faint }}>
                                        Variables
                                        {parser.summary?.comp3_variables > 0 && (
                                            <span className="ml-2" style={{ color: C.amber }}>{parser.summary.comp3_variables} COMP-3</span>
                                        )}
                                    </div>
                                    <div className="relative">
                                        <Search size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2" style={{ color: '#D1D5DB' }} />
                                        <input
                                            type="text"
                                            value={varFilter}
                                            onChange={(e) => setVarFilter(e.target.value)}
                                            placeholder="Filter..."
                                            className="border text-[10px] font-mono pl-7 pr-3 py-1.5 w-48 focus:outline-none rounded-sm"
                                            style={{ borderColor: C.border, color: C.body, backgroundColor: C.bg }}
                                        />
                                    </div>
                                </div>

                                {/* Table Header */}
                                <div className="grid grid-cols-[1fr_80px] gap-3 px-4 py-2 rounded-sm mb-1" style={{ backgroundColor: C.bgAlt }}>
                                    <span className="text-[9px] uppercase tracking-[0.12em]" style={{ color: C.faint }}>Name / Definition</span>
                                    <span className="text-[9px] uppercase tracking-[0.12em] text-right" style={{ color: C.faint }}>Type</span>
                                </div>

                                <div>
                                    {parser.variables
                                        ?.filter(v => !varFilter || v.raw?.toLowerCase().includes(varFilter.toLowerCase()))
                                        .map((v, i) => (
                                        <div key={i} className="grid grid-cols-[1fr_80px] gap-3 px-4 py-2.5 border-b" style={{
                                            borderColor: C.borderLight,
                                            backgroundColor: v.comp3 ? C.amberBg : i % 2 === 0 ? C.bg : C.bgAlt,
                                        }}>
                                            <span className="text-[10px] font-mono" style={{ color: v.comp3 ? C.amber : C.body }}>{v.raw}</span>
                                            <span className="text-right">
                                                {v.comp3 && (
                                                    <span className="text-[8px] font-mono uppercase px-2 py-0.5 rounded-sm font-medium" style={{ backgroundColor: '#FEF3C7', color: '#92400E', border: `1px solid ${C.amberBorder}` }}>
                                                        COMP-3
                                                    </span>
                                                )}
                                            </span>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Control Flow */}
                            {parser.control_flow?.length > 0 && (
                                <div className="mb-6">
                                    <div className="text-[10px] uppercase tracking-[0.12em] mb-3" style={{ color: C.faint }}>Control Flow</div>
                                    <div className="space-y-1">
                                        {parser.control_flow.map((edge, i) => (
                                            <div key={i} className="flex items-center gap-4 px-4 py-2.5 border rounded-sm" style={{ borderColor: C.borderLight }}>
                                                <span className="text-[10px] font-mono" style={{ color: C.navy }}>{edge.from}</span>
                                                <ArrowRight size={12} style={{ color: '#D1D5DB' }} className="shrink-0" />
                                                <span className="text-[10px] font-mono" style={{ color: C.body }}>{edge.to}</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* COMPUTE Statements */}
                            {parser.computes?.length > 0 && (
                                <div className="mb-6">
                                    <div className="text-[10px] uppercase tracking-[0.12em] mb-3" style={{ color: C.faint }}>COMPUTE Statements</div>
                                    {Object.entries(groupByParagraph(parser.computes)).map(([para, items]) => (
                                        <div key={para} className="mb-3">
                                            <div className="text-[9px] uppercase tracking-[0.12em] mb-1" style={{ color: '#D1D5DB' }}>{para}</div>
                                            {items.map((c, i) => (
                                                <div key={i} className="px-4 py-2.5 border rounded-sm mb-1" style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}>
                                                    <span className="text-[10px] font-mono break-all" style={{ color: C.muted }}>{c.statement}</span>
                                                </div>
                                            ))}
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* IF Conditions */}
                            {parser.conditions?.length > 0 && (
                                <div className="mb-6">
                                    <div className="text-[10px] uppercase tracking-[0.12em] mb-3" style={{ color: C.faint }}>Business Rules (IF)</div>
                                    {Object.entries(groupByParagraph(parser.conditions)).map(([para, items]) => (
                                        <div key={para} className="mb-3">
                                            <div className="text-[9px] uppercase tracking-[0.12em] mb-1" style={{ color: '#D1D5DB' }}>{para}</div>
                                            {items.map((c, i) => (
                                                <div key={i} className="px-4 py-2.5 border rounded-sm mb-1" style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}>
                                                    <span className="text-[10px] font-mono break-all" style={{ color: C.muted }}>{c.statement}</span>
                                                </div>
                                            ))}
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* Warnings */}
                            {((parser.cycles?.length > 0) || (parser.unreachable?.length > 0)) && (
                                <div className="space-y-4">
                                    {parser.cycles?.length > 0 && (
                                        <div>
                                            <div className="text-[10px] uppercase tracking-[0.12em] mb-2" style={{ color: C.amber }}>Cycles Detected</div>
                                            {parser.cycles.map((cycle, i) => (
                                                <div key={i} className="flex items-center gap-3 px-4 py-2.5 border rounded-sm mb-1" style={{ borderColor: C.amberBorder, backgroundColor: C.amberBg }}>
                                                    <AlertTriangle size={12} style={{ color: C.amber }} className="shrink-0" strokeWidth={1.5} />
                                                    <span className="text-[10px] font-mono" style={{ color: C.amber }}>{cycle.join(' \u2192 ')} \u2192 {cycle[0]}</span>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                    {parser.unreachable?.length > 0 && (
                                        <div>
                                            <div className="text-[10px] uppercase tracking-[0.12em] mb-2" style={{ color: C.red }}>Unreachable Code</div>
                                            {parser.unreachable.map((name, i) => (
                                                <div key={i} className="flex items-center gap-3 px-4 py-2.5 border rounded-sm mb-1" style={{ borderColor: C.redBorder, backgroundColor: C.redBg }}>
                                                    <XCircle size={12} style={{ color: C.red }} className="shrink-0" strokeWidth={1.5} />
                                                    <span className="text-[10px] font-mono" style={{ color: C.red }}>{name}</span>
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}
                        </Section>
                    )}

                    {/* ═══ Generated Python (Collapsible) ═══ */}
                    {generatedPython && (
                        <div className="border-b" style={{ borderColor: C.border }}>
                            <button
                                onClick={() => setShowCode(!showCode)}
                                className="w-full flex items-center justify-between py-5 text-left group"
                            >
                                <div className="flex items-center gap-4">
                                    <Code2 size={16} strokeWidth={1.5} style={{ color: C.faint }} />
                                    <span className="text-[13px] font-semibold uppercase tracking-[0.12em]" style={{ color: C.text }}>Verification Model</span>
                                    <span className="text-[9px] uppercase px-2.5 py-1 rounded-sm tracking-wider font-medium" style={{ backgroundColor: C.greenBg, color: C.green, border: `1px solid ${C.greenBorder}` }}>
                                        Decimal-Safe
                                    </span>
                                </div>
                                <div className="flex items-center gap-4">
                                    {!showCode && (
                                        <span className="text-[11px] font-mono" style={{ color: C.faint }}>
                                            {generatedPython.length.toLocaleString()} chars &middot; {parser?.summary?.paragraphs ?? 0} paragraphs translated
                                        </span>
                                    )}
                                    {showCode && (
                                        <button
                                            onClick={(e) => { e.stopPropagation(); copyToClipboard(); }}
                                            className="flex items-center gap-2 px-4 py-1.5 border text-[10px] uppercase tracking-wider transition-all duration-200 hover:opacity-80 rounded-sm"
                                            style={{ borderColor: C.border, color: C.muted }}
                                        >
                                            {copySuccess ? <Check size={11} /> : <Copy size={11} />}
                                            {copySuccess ? 'Copied' : 'Copy'}
                                        </button>
                                    )}
                                    <ChevronDown size={16} style={{ color: C.faint }} className={`transition-transform duration-200 ${showCode ? 'rotate-180' : ''}`} />
                                </div>
                            </button>
                            <div className="collapse-panel" data-open={showCode}>
                                <div className="overflow-auto max-h-[600px] rounded-sm mb-8" style={{ backgroundColor: C.bgAlt, border: `1px solid ${C.border}` }}>
                                    <div className="flex">
                                        <div className="w-12 flex-shrink-0 border-r select-none py-4 pr-2" style={{ borderColor: C.borderLight, backgroundColor: '#F0F1F3' }}>
                                            {generatedPython.split('\n').map((_, i) => (
                                                <div key={i} className="text-right text-[10px] font-mono leading-relaxed pr-1" style={{ color: '#D1D5DB' }}>
                                                    {i + 1}
                                                </div>
                                            ))}
                                        </div>
                                        <pre className="flex-1 p-5 font-mono text-sm leading-relaxed whitespace-pre overflow-x-auto" style={{ color: C.text }}>
                                            <code>{generatedPython}</code>
                                        </pre>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ═══ Verification Checklist ═══ */}
                    {verification?.checklist && verification.checklist.length > 0 && (
                        <Section title="Verification Checklist" icon={ShieldCheck} count={verification.checklist.length} defaultOpen>
                            <div className="space-y-0">
                                {verification.checklist.map((item, i) => {
                                    const statusCfg = {
                                        PASS: { borderColor: C.green, textColor: C.green, char: '\u2713' },
                                        FAIL: { borderColor: C.red, textColor: C.red, char: '\u2717' },
                                        WARN: { borderColor: C.amber, textColor: C.amber, char: '!' },
                                    };
                                    const cfg = statusCfg[item.status] || statusCfg.WARN;
                                    return (
                                        <div key={i} className="flex items-start gap-4 pl-5 pr-5 py-4 border-b" style={{
                                            borderColor: C.border,
                                            borderLeftWidth: 3,
                                            borderLeftColor: cfg.borderColor,
                                            borderLeftStyle: 'solid',
                                        }}>
                                            <span className="text-[14px] font-mono font-bold shrink-0 w-5 text-center" style={{ color: cfg.textColor }}>{cfg.char}</span>
                                            <div className="flex-1 pl-2">
                                                <span className="text-[13px]" style={{ color: C.text }}>{item.item}</span>
                                                {item.note && <p className="text-[11px] mt-1.5 leading-relaxed" style={{ color: C.muted }}>{item.note}</p>}
                                            </div>
                                            <span className="text-[10px] font-mono uppercase tracking-wider font-bold" style={{ color: cfg.textColor }}>{item.status}</span>
                                        </div>
                                    );
                                })}
                            </div>
                        </Section>
                    )}

                    {/* ═══ Human Review Flags ═══ */}
                    {verification?.human_review_items && verification.human_review_items.length > 0 && (
                        <Section title="Human Review Flags" icon={Eye} count={verification.human_review_items.length} defaultOpen>
                            <div className="space-y-4">
                                {verification.human_review_items.map((item, i) => {
                                    const severityCfg = {
                                        HIGH: { borderColor: C.red, bgColor: '#FFF5F5', badgeBg: C.redBg, badgeColor: C.red, badgeBorder: C.redBorder },
                                        MEDIUM: { borderColor: '#D4A84C', bgColor: '#FFFBF0', badgeBg: C.amberBg, badgeColor: C.amber, badgeBorder: C.amberBorder },
                                        LOW: { borderColor: '#D4A84C', bgColor: '#FFFBF0', badgeBg: C.bgAlt, badgeColor: C.muted, badgeBorder: C.border },
                                    };
                                    const cfg = severityCfg[item.severity] || severityCfg.MEDIUM;
                                    return (
                                        <div key={i} className="p-5 space-y-3" style={{
                                            borderLeftWidth: 3,
                                            borderLeftStyle: 'solid',
                                            borderLeftColor: cfg.borderColor,
                                            backgroundColor: cfg.bgColor,
                                        }}>
                                            <div className="flex items-center gap-3">
                                                <span className="text-[10px] font-mono uppercase px-3 py-1 font-bold tracking-wider" style={{
                                                    backgroundColor: cfg.badgeBg,
                                                    color: cfg.badgeColor,
                                                    border: `1px solid ${cfg.badgeBorder}`,
                                                }}>
                                                    {item.severity}
                                                </span>
                                                <span className="text-[13px] font-medium" style={{ color: C.text }}>{item.item}</span>
                                            </div>
                                            {item.reason && (
                                                <p className="text-[12px] leading-relaxed pl-1" style={{ color: C.muted }}>{item.reason}</p>
                                            )}
                                        </div>
                                    );
                                })}
                            </div>
                        </Section>
                    )}

                    {/* ═══ External Dependencies ═══ */}
                    {parser?.exec_dependencies?.length > 0 && (() => {
                        const ea = parser.exec_analysis;
                        const taint = ea?.variable_taint || {};
                        const taintedCount = taint.tainted?.length || 0;
                        const usedCount = taint.used?.length || 0;
                        const controlCount = taint.control?.length || 0;
                        const blocks = ea?.parsed_blocks || parser.exec_dependencies;
                        const branches = ea?.sqlcode_branches || [];

                        const taintCfg = {
                            TAINTED: { color: C.amber, bg: C.amberBg, border: C.amberBorder },
                            USED:    { color: C.navy, bg: '#F0F4FF', border: '#C7D2FE' },
                            CONTROL: { color: C.green, bg: C.greenBg, border: C.greenBorder },
                        };

                        return (
                            <Section
                                title="External Dependencies"
                                icon={Database}
                                count={parser.exec_dependencies.length}
                                badge="MANUAL REVIEW"
                                defaultOpen
                            >
                                {/* Summary bar */}
                                <div className="grid grid-cols-3 gap-4 mb-8">
                                    {[
                                        { label: 'TAINTED', value: taintedCount, ...taintCfg.TAINTED },
                                        { label: 'USED', value: usedCount, ...taintCfg.USED },
                                        { label: 'CONTROL', value: controlCount, ...taintCfg.CONTROL },
                                    ].map((stat) => (
                                        <div key={stat.label} className="p-4 border" style={{
                                            borderColor: stat.value > 0 ? stat.border : C.border,
                                            backgroundColor: stat.value > 0 ? stat.bg : C.bg,
                                            borderTopWidth: 3,
                                            borderTopColor: stat.color,
                                        }}>
                                            <div className="text-2xl font-mono font-bold" style={{
                                                color: stat.value > 0 ? stat.color : '#D1D5DB',
                                            }}>{stat.value}</div>
                                            <div className="text-[9px] uppercase tracking-[0.12em] mt-1" style={{ color: C.faint }}>
                                                {stat.label}
                                            </div>
                                        </div>
                                    ))}
                                </div>

                                {/* Per-block cards */}
                                <div className="space-y-4">
                                    {blocks.map((block, i) => {
                                        const verb = block.verb || block.parsed?.verb || 'UNKNOWN';
                                        const execType = block.exec_type || block.type || 'EXEC SQL';
                                        const preview = block.body_preview || '';
                                        const parsed = block.parsed || {};
                                        const intoVars = parsed.into_vars || [];
                                        const whereVars = parsed.where_vars || parsed.from_vars || [];

                                        return (
                                            <div key={i} className="p-5 space-y-3" style={{
                                                borderLeftWidth: 3,
                                                borderLeftStyle: 'solid',
                                                borderLeftColor: C.amber,
                                                backgroundColor: C.bg,
                                            }}>
                                                <div className="flex items-center gap-3">
                                                    <span className="text-[10px] font-mono uppercase px-3 py-1 font-bold tracking-wider" style={{
                                                        backgroundColor: C.amberBg,
                                                        color: C.amber,
                                                        border: `1px solid ${C.amberBorder}`,
                                                    }}>
                                                        {execType}
                                                    </span>
                                                    <span className="text-[13px] font-mono font-semibold" style={{ color: C.text }}>
                                                        {verb}
                                                    </span>
                                                </div>
                                                <pre className="text-[11px] font-mono leading-relaxed p-3 overflow-x-auto" style={{
                                                    color: C.muted,
                                                    backgroundColor: C.bgAlt,
                                                    border: `1px solid ${C.borderLight}`,
                                                }}>
                                                    {preview}
                                                </pre>
                                                {intoVars.length > 0 && (
                                                    <div className="flex flex-wrap gap-2">
                                                        <span className="text-[9px] uppercase tracking-wider font-semibold" style={{ color: C.amber }}>
                                                            TAINTED:
                                                        </span>
                                                        {intoVars.map((v, j) => (
                                                            <span key={j} className="text-[10px] font-mono px-2 py-0.5" style={{
                                                                backgroundColor: C.amberBg,
                                                                color: C.amber,
                                                                border: `1px solid ${C.amberBorder}`,
                                                            }}>{v}</span>
                                                        ))}
                                                    </div>
                                                )}
                                                {whereVars.length > 0 && (
                                                    <div className="flex flex-wrap gap-2">
                                                        <span className="text-[9px] uppercase tracking-wider font-semibold" style={{ color: C.navy }}>
                                                            USED:
                                                        </span>
                                                        {whereVars.map((v, j) => (
                                                            <span key={j} className="text-[10px] font-mono px-2 py-0.5" style={{
                                                                backgroundColor: '#F0F4FF',
                                                                color: C.navy,
                                                                border: '1px solid #C7D2FE',
                                                            }}>{v}</span>
                                                        ))}
                                                    </div>
                                                )}
                                            </div>
                                        );
                                    })}
                                </div>

                                {/* SQLCODE branch mapping */}
                                {branches.length > 0 && (
                                    <div className="mt-6 space-y-3">
                                        <div className="text-[10px] uppercase tracking-[0.15em] font-semibold pb-2" style={{ color: C.navy }}>
                                            SQLCODE Branch Mapping
                                        </div>
                                        {branches.map((br, i) => {
                                            const branchCfg = {
                                                success: { color: C.green, bg: C.greenBg, border: C.greenBorder },
                                                error: { color: C.red, bg: C.redBg, border: C.redBorder },
                                                not_found: { color: C.amber, bg: C.amberBg, border: C.amberBorder },
                                                severe: { color: C.red, bg: C.redBg, border: C.redBorder },
                                            };
                                            const cfg = branchCfg[br.branch] || branchCfg.error;
                                            return (
                                                <div key={i} className="flex items-center gap-4 p-4" style={{
                                                    backgroundColor: cfg.bg,
                                                    border: `1px solid ${cfg.border}`,
                                                }}>
                                                    <span className="text-[10px] font-mono uppercase px-2 py-0.5 font-bold tracking-wider" style={{
                                                        color: cfg.color,
                                                        border: `1px solid ${cfg.border}`,
                                                        backgroundColor: C.bg,
                                                    }}>
                                                        {br.branch}
                                                    </span>
                                                    <span className="text-[12px] font-mono" style={{ color: C.text }}>
                                                        {br.condition}
                                                    </span>
                                                    <span className="text-[11px] ml-auto" style={{ color: cfg.color }}>
                                                        {br.meaning}
                                                    </span>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}

                                {/* Taint summary */}
                                {(taint.tainted?.length > 0 || taint.control?.length > 0) && (
                                    <div className="mt-6 p-4" style={{ backgroundColor: C.bgAlt, border: `1px solid ${C.borderLight}` }}>
                                        <div className="text-[10px] uppercase tracking-[0.15em] font-semibold pb-3" style={{ color: C.navy }}>
                                            Variable Impact Summary
                                        </div>
                                        <div className="space-y-2">
                                            {taint.tainted?.map((t, i) => (
                                                <div key={`t-${i}`} className="flex items-center gap-3 text-[11px]">
                                                    <span className="font-mono font-semibold" style={{ color: C.amber }}>{t.var}</span>
                                                    <span style={{ color: C.faint }}>←</span>
                                                    <span style={{ color: C.muted }}>{t.source}: {t.detail}</span>
                                                </div>
                                            ))}
                                            {taint.control?.map((c, i) => (
                                                <div key={`c-${i}`} className="flex items-center gap-3 text-[11px]">
                                                    <span className="font-mono font-semibold" style={{ color: C.green }}>{c.var}</span>
                                                    <span style={{ color: C.faint }}>—</span>
                                                    <span style={{ color: C.muted }}>{c.detail}</span>
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </Section>
                        );
                    })()}

                    {/* ═══ Arithmetic Risk Analysis ═══ */}
                    {result?.arithmetic_risks?.length > 0 && (() => {
                        const s = result.arithmetic_summary || {};
                        const riskCfg = {
                            SAFE:     { borderColor: C.green, bgColor: C.bg, badgeBg: C.greenBg, badgeColor: C.green, badgeBorder: C.greenBorder, reasonColor: C.green },
                            WARN:     { borderColor: C.amber, bgColor: C.bg, badgeBg: C.amberBg, badgeColor: C.amber, badgeBorder: C.amberBorder, reasonColor: C.amber },
                            CRITICAL: { borderColor: C.red, bgColor: C.bg, badgeBg: C.redBg, badgeColor: C.red, badgeBorder: C.redBorder, reasonColor: C.red },
                        };
                        const sectionBadge = s.critical > 0 ? 'CRITICAL' : s.warn > 0 ? 'WARN' : undefined;
                        return (
                            <Section
                                title="Arithmetic Risk Analysis"
                                icon={AlertTriangle}
                                count={result.arithmetic_risks.length}
                                badge={sectionBadge}
                                defaultOpen
                            >
                                {/* Summary bar */}
                                <div className="grid grid-cols-3 gap-4 mb-8">
                                    {[
                                        { label: 'SAFE', value: s.safe ?? 0, color: C.green, bg: C.greenBg, border: C.greenBorder, topColor: C.green },
                                        { label: 'WARNING', value: s.warn ?? 0, color: C.amber, bg: s.warn > 0 ? C.amberBg : C.bg, border: s.warn > 0 ? C.amberBorder : C.border, topColor: C.amber },
                                        { label: 'CRITICAL', value: s.critical ?? 0, color: C.red, bg: s.critical > 0 ? C.redBg : C.bg, border: s.critical > 0 ? C.redBorder : C.border, topColor: C.red },
                                    ].map((stat) => (
                                        <div key={stat.label} className="p-4 border rounded-sm" style={{ borderColor: stat.border, backgroundColor: stat.bg, borderTopWidth: 3, borderTopColor: stat.topColor }}>
                                            <div className="text-2xl font-mono font-bold" style={{ color: stat.value > 0 ? stat.color : '#D1D5DB' }}>{stat.value}</div>
                                            <div className="text-[9px] uppercase tracking-[0.12em] mt-1" style={{ color: C.faint }}>{stat.label}</div>
                                        </div>
                                    ))}
                                </div>

                                {/* Per-COMPUTE risk cards */}
                                <div className="space-y-4">
                                    {result.arithmetic_risks.map((risk, i) => {
                                        const cfg = riskCfg[risk.status] || riskCfg.WARN;
                                        return (
                                            <div key={i} className="p-5 space-y-3" style={{
                                                borderLeftWidth: 3,
                                                borderLeftStyle: 'solid',
                                                borderLeftColor: cfg.borderColor,
                                                backgroundColor: C.bg,
                                                borderBottom: `1px solid ${C.border}`,
                                            }}>
                                                <div className="flex items-start gap-3">
                                                    <span className="shrink-0 px-2.5 py-0.5 text-[9px] font-mono font-bold border tracking-wider rounded-sm" style={{
                                                        backgroundColor: cfg.badgeBg,
                                                        color: cfg.badgeColor,
                                                        borderColor: cfg.badgeBorder,
                                                    }}>
                                                        {risk.status}
                                                    </span>
                                                    <span className="text-[11px] font-mono break-all flex-1" style={{ color: C.body }}>{risk.compute}</span>
                                                    <span className="text-[10px] font-mono shrink-0" style={{ color: C.faint }}>{risk.paragraph}</span>
                                                </div>
                                                <div className="grid grid-cols-2 gap-x-8 gap-y-1.5 pl-1 text-[10px] font-mono">
                                                    <div style={{ color: C.muted }}>
                                                        Target: <span style={{ color: C.body }}>{risk.target?.name}</span>
                                                        <span className="ml-2" style={{ color: '#D1D5DB' }}>PIC {risk.target?.pic}</span>
                                                        <span className="ml-2" style={{ color: '#D1D5DB' }}>max {risk.target?.max_value}</span>
                                                    </div>
                                                    <div style={{ color: C.muted }}>
                                                        Operation: <span style={{ color: C.body }}>{risk.operation}</span>
                                                        <span className="ml-3" style={{ color: '#D1D5DB' }}>Worst-case: </span>
                                                        <span style={{ color: C.body }}>{risk.worst_case}</span>
                                                    </div>
                                                    {risk.operands?.map((op, j) => (
                                                        <div key={j} style={{ color: C.muted }}>
                                                            Operand: <span style={{ color: C.body }}>{op.name}</span>
                                                            <span className="ml-2" style={{ color: '#D1D5DB' }}>PIC {op.pic}</span>
                                                            <span className="ml-2" style={{ color: '#D1D5DB' }}>max {op.max_value}</span>
                                                        </div>
                                                    ))}
                                                </div>
                                                <div className="pl-1 text-[10px]">
                                                    <span style={{ color: C.muted }}>Reason: </span>
                                                    <span style={{ color: cfg.reasonColor }}>{risk.reason}</span>
                                                </div>
                                            </div>
                                        );
                                    })}
                                </div>
                            </Section>
                        );
                    })()}

                    {/* Reset */}
                    <div className="pt-8">
                        <button
                            onClick={handleReset}
                            className="flex items-center gap-2 px-8 py-3 border text-[10px] uppercase tracking-[0.12em] transition-all duration-200 hover:opacity-80 rounded-sm"
                            style={{ borderColor: C.border, color: C.faint }}
                        >
                            <RefreshCw size={13} strokeWidth={1.5} />
                            New Analysis
                        </button>
                    </div>
                </div>
            )}

            {/* ── MULTI-PROGRAM RESULTS ── */}
            {depResult && !result && (() => {
                const tree = depResult.dependency_tree || {};
                const agg = depResult.aggregate || {};
                const progResults = depResult.program_results || {};
                const isSystemVerified = agg.verification_status === 'VERIFIED';

                const renderTree = (name, depth = 0) => {
                    const node = tree.tree?.[name];
                    if (!node) return null;
                    const progData = progResults[name];
                    const progSummary = progData?.analysis?.summary || {};
                    const fileVerified = progData?.verification_status === 'VERIFIED';
                    return (
                        <div key={name}>
                            <div className="flex items-center gap-3 py-2" style={{ paddingLeft: depth * 24 }}>
                                {depth > 0 && <ArrowRight size={12} style={{ color: '#D1D5DB' }} />}
                                <span className="text-[12px] font-mono font-semibold" style={{ color: C.navy }}>{name}</span>
                                <span className="text-[9px] font-mono uppercase px-2 py-0.5" style={{
                                    backgroundColor: progData ? (fileVerified ? C.greenBg : C.amberBg) : C.bgAlt,
                                    color: progData ? (fileVerified ? C.green : C.amber) : C.faint,
                                    border: `1px solid ${progData ? (fileVerified ? C.greenBorder : C.amberBorder) : C.border}`,
                                }}>
                                    {progData ? (fileVerified ? 'VERIFIED' : 'MANUAL REVIEW') : 'UNRESOLVED'}
                                </span>
                                {progData && (
                                    <span className="text-[10px]" style={{ color: C.muted }}>
                                        {progSummary.paragraphs ?? 0} para / {progSummary.variables ?? 0} vars
                                    </span>
                                )}
                            </div>
                            {node.calls?.map(child => renderTree(child, depth + 1))}
                        </div>
                    );
                };

                return (
                    <div className="space-y-0 fade-in">
                        {/* Hero */}
                        <div className="mb-10 pb-10 pt-12 border-b" style={{ borderColor: C.border }}>
                            <div className="flex items-center justify-between mb-8">
                                <div className="flex items-center gap-5">
                                    <div className="w-14 h-14 flex items-center justify-center" style={{
                                        backgroundColor: isSystemVerified ? C.greenBg : C.amberBg,
                                    }}>
                                        {isSystemVerified
                                            ? <CheckCircle size={28} strokeWidth={1.5} style={{ color: C.green }} />
                                            : <AlertTriangle size={28} strokeWidth={1.5} style={{ color: C.amber }} />
                                        }
                                    </div>
                                    <div>
                                        <h2 className="text-xl font-semibold tracking-[0.08em] uppercase" style={{ color: C.text }}>
                                            {isSystemVerified ? 'System Verified' : 'System Requires Manual Review'}
                                        </h2>
                                        <p className="text-[11px] mt-1 tracking-wide" style={{ color: C.faint }}>
                                            {agg.total_programs} programs analyzed
                                        </p>
                                    </div>
                                </div>
                                <div className="px-8 py-3.5 text-base font-bold uppercase tracking-widest" style={{
                                    backgroundColor: isSystemVerified ? C.navy : C.bg,
                                    color: isSystemVerified ? '#FFFFFF' : C.amber,
                                    border: isSystemVerified ? 'none' : `2px solid ${C.amberBorder}`,
                                }}>
                                    {isSystemVerified ? 'VERIFIED' : 'MANUAL REVIEW'}
                                </div>
                            </div>
                            <div className="flex items-center gap-6 text-[12px]" style={{ color: C.muted }}>
                                <span><strong style={{ color: C.text }}>{agg.total_programs}</strong> Programs</span>
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: C.green }}>{agg.verified_programs ?? agg.total_programs}</strong> Verified</span>
                                {(agg.manual_review_programs ?? 0) > 0 && <>
                                    <span style={{ color: C.border }}>|</span>
                                    <span><strong style={{ color: C.amber }}>{agg.manual_review_programs}</strong> Manual Review</span>
                                </>}
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: C.text }}>{agg.total_paragraphs}</strong> Paragraphs</span>
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: C.text }}>{agg.total_variables}</strong> Variables</span>
                                <span style={{ color: C.border }}>|</span>
                                <span><strong style={{ color: agg.total_comp3 > 0 ? C.amber : C.text }}>{agg.total_comp3}</strong> COMP-3</span>
                            </div>
                        </div>

                        {/* Dependency Tree */}
                        <Section title="Program Dependencies" icon={GitBranch} count={Object.keys(tree.tree || {}).length} defaultOpen>
                            <div className="grid grid-cols-3 gap-4 mb-8">
                                {[
                                    { label: 'PROGRAMS', value: agg.total_programs, color: C.navy, bg: '#F0F4FF', border: '#C7D2FE' },
                                    { label: 'UNRESOLVED', value: tree.unresolved?.length || 0, color: C.amber, bg: C.amberBg, border: C.amberBorder },
                                    { label: 'DYNAMIC CALLS', value: tree.dynamic_calls?.length || 0, color: C.amber, bg: C.amberBg, border: C.amberBorder },
                                ].map(stat => (
                                    <div key={stat.label} className="p-4 border" style={{
                                        borderColor: stat.value > 0 ? stat.border : C.border,
                                        backgroundColor: stat.value > 0 ? stat.bg : C.bg,
                                        borderTopWidth: 3,
                                        borderTopColor: stat.color,
                                    }}>
                                        <div className="text-2xl font-mono font-bold" style={{ color: stat.value > 0 ? stat.color : '#D1D5DB' }}>
                                            {stat.value}
                                        </div>
                                        <div className="text-[9px] uppercase tracking-[0.12em] mt-1" style={{ color: C.faint }}>
                                            {stat.label}
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {/* Tree visualization */}
                            <div className="p-5 border mb-6" style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}>
                                <div className="text-[10px] uppercase tracking-[0.15em] font-semibold mb-4" style={{ color: C.navy }}>
                                    Call Hierarchy
                                </div>
                                {tree.root && renderTree(tree.root)}
                            </div>

                            {/* Unresolved warnings */}
                            {tree.unresolved?.length > 0 && (
                                <div className="space-y-2 mb-6">
                                    <div className="text-[10px] uppercase tracking-[0.15em] font-semibold" style={{ color: C.amber }}>
                                        Unresolved Programs
                                    </div>
                                    {tree.unresolved.map((name, i) => (
                                        <div key={i} className="flex items-center gap-3 px-4 py-3 border" style={{ borderColor: C.amberBorder, backgroundColor: C.amberBg }}>
                                            <AlertTriangle size={14} style={{ color: C.amber }} />
                                            <span className="text-[12px] font-mono" style={{ color: C.amber }}>{name}</span>
                                            <span className="text-[10px] ml-auto" style={{ color: C.muted }}>Called but not uploaded</span>
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* Dynamic call warnings */}
                            {tree.dynamic_calls?.length > 0 && (
                                <div className="space-y-2 mb-6">
                                    <div className="text-[10px] uppercase tracking-[0.15em] font-semibold" style={{ color: C.amber }}>
                                        Dynamic Calls
                                    </div>
                                    {tree.dynamic_calls.map((dc, i) => (
                                        <div key={i} className="flex items-center gap-3 px-4 py-3 border" style={{ borderColor: C.amberBorder, backgroundColor: C.amberBg }}>
                                            <AlertTriangle size={14} style={{ color: C.amber }} />
                                            <span className="text-[12px] font-mono" style={{ color: C.text }}>{dc.program}</span>
                                            <span className="text-[10px]" style={{ color: C.muted }}>calls variable</span>
                                            <span className="text-[12px] font-mono" style={{ color: C.amber }}>{dc.variable}</span>
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* Parameter mappings */}
                            {Object.entries(progResults).map(([progName, progData]) => {
                                const mappings = progData.parameter_mappings || [];
                                if (mappings.length === 0) return null;
                                return (
                                    <div key={progName} className="mb-4">
                                        <div className="text-[10px] uppercase tracking-[0.15em] font-semibold mb-2" style={{ color: C.navy }}>
                                            {progName} Parameter Mappings
                                        </div>
                                        {mappings.map((pm, j) => (
                                            <div key={j} className="mb-2 p-3 border" style={{ borderColor: C.borderLight }}>
                                                <div className="text-[10px] font-mono font-semibold mb-2" style={{ color: C.text }}>
                                                    CALL {pm.target}
                                                </div>
                                                <div className="space-y-1">
                                                    {pm.mappings.map((m, k) => (
                                                        <div key={k} className="flex items-center gap-3 text-[11px]">
                                                            <span className="font-mono" style={{ color: C.navy }}>{m.caller_var}</span>
                                                            <ArrowRight size={12} style={{ color: '#D1D5DB' }} />
                                                            <span className="font-mono" style={{ color: C.green }}>{m.callee_var}</span>
                                                        </div>
                                                    ))}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                );
                            })}
                        </Section>

                        {/* Per-program breakdown */}
                        {Object.entries(progResults).map(([progName, progData]) => {
                            const analysis = progData.analysis || {};
                            const summary = analysis.summary || {};
                            const hasExecDeps = (analysis.exec_dependencies || []).length > 0;
                            const fileVerified = progData.verification_status === 'VERIFIED';
                            const arithSummary = progData.arithmetic_summary || {};
                            const hasArith = (arithSummary.total ?? 0) > 0;
                            return (
                                <Section key={progName} title={progName} icon={FileCode} count={summary.paragraphs ?? 0} defaultOpen={false}>
                                    {/* Per-file verdict */}
                                    <div className="flex items-center gap-3 mb-4">
                                        <span className="text-[9px] font-mono uppercase px-3 py-1" style={{
                                            backgroundColor: fileVerified ? C.greenBg : C.amberBg,
                                            color: fileVerified ? C.green : C.amber,
                                            border: `1px solid ${fileVerified ? C.greenBorder : C.amberBorder}`,
                                        }}>
                                            {fileVerified ? 'VERIFIED' : 'MANUAL REVIEW'}
                                        </span>
                                        {progData.emit_counts && (
                                            <span className="text-[10px]" style={{ color: C.muted }}>
                                                {progData.emit_counts.total_emitted ?? 0} statements emitted
                                            </span>
                                        )}
                                    </div>

                                    <div className="grid grid-cols-4 gap-3 mb-4">
                                        {[
                                            { label: 'Paragraphs', value: summary.paragraphs ?? 0 },
                                            { label: 'Variables', value: summary.variables ?? 0 },
                                            { label: 'COMP-3', value: summary.comp3_variables ?? 0, warn: true },
                                            { label: 'Computes', value: summary.compute_statements ?? 0 },
                                        ].map(stat => (
                                            <div key={stat.label} className="p-3 border" style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt }}>
                                                <div className="text-lg font-mono font-bold" style={{
                                                    color: stat.warn && stat.value > 0 ? C.amber : C.text,
                                                }}>{stat.value}</div>
                                                <div className="text-[9px] uppercase tracking-[0.08em] mt-0.5" style={{ color: C.faint }}>{stat.label}</div>
                                            </div>
                                        ))}
                                    </div>

                                    {/* Arithmetic risk summary */}
                                    {hasArith && (
                                        <div className="grid grid-cols-3 gap-2 mb-4">
                                            {[
                                                { label: 'SAFE', value: arithSummary.safe ?? 0, color: C.green, bg: C.greenBg },
                                                { label: 'WARN', value: arithSummary.warn ?? 0, color: C.amber, bg: C.amberBg },
                                                { label: 'CRITICAL', value: arithSummary.critical ?? 0, color: C.red, bg: C.redBg },
                                            ].map(s => (
                                                <div key={s.label} className="p-2 border text-center" style={{
                                                    borderColor: C.borderLight,
                                                    backgroundColor: s.value > 0 ? s.bg : C.bg,
                                                }}>
                                                    <div className="text-lg font-mono font-bold" style={{ color: s.value > 0 ? s.color : '#D1D5DB' }}>
                                                        {s.value}
                                                    </div>
                                                    <div className="text-[8px] uppercase tracking-wider" style={{ color: C.faint }}>{s.label}</div>
                                                </div>
                                            ))}
                                        </div>
                                    )}

                                    {hasExecDeps && (
                                        <div className="flex items-center gap-2 px-4 py-2 mb-2" style={{ backgroundColor: C.amberBg, border: `1px solid ${C.amberBorder}` }}>
                                            <AlertTriangle size={12} style={{ color: C.amber }} />
                                            <span className="text-[10px] uppercase tracking-wider" style={{ color: C.amber }}>
                                                {analysis.exec_dependencies.length} External Dependencies
                                            </span>
                                        </div>
                                    )}

                                    {progData.linkage?.length > 0 && (
                                        <div className="mt-3 mb-4">
                                            <div className="text-[9px] uppercase tracking-wider mb-2" style={{ color: C.faint }}>Linkage Section</div>
                                            <div className="flex flex-wrap gap-2">
                                                {progData.linkage.map((v, i) => (
                                                    <span key={i} className="text-[10px] font-mono px-2 py-1 border" style={{
                                                        borderColor: C.borderLight, backgroundColor: C.bgAlt,
                                                    }}>
                                                        {v.name} {v.pic}
                                                    </span>
                                                ))}
                                            </div>
                                        </div>
                                    )}

                                    {/* Generated Python */}
                                    {progData.generated_python && (
                                        <div className="mt-4">
                                            <div className="flex items-center justify-between mb-2">
                                                <button
                                                    onClick={() => toggleProgramCode(progName)}
                                                    className="flex items-center gap-2 text-[9px] uppercase tracking-wider"
                                                    style={{ color: C.faint }}
                                                >
                                                    {expandedPrograms.has(progName)
                                                        ? <ChevronDown size={12} />
                                                        : <ChevronRight size={12} />
                                                    }
                                                    Verification Model
                                                </button>
                                                {expandedPrograms.has(progName) && (
                                                    <button
                                                        onClick={() => navigator.clipboard.writeText(progData.generated_python)}
                                                        className="text-[9px] px-2 py-1 border uppercase tracking-wider"
                                                        style={{ borderColor: C.border, color: C.faint }}
                                                    >
                                                        Copy
                                                    </button>
                                                )}
                                            </div>
                                            {expandedPrograms.has(progName) && (
                                                <pre className="p-4 border text-[11px] font-mono overflow-x-auto max-h-[400px] overflow-y-auto"
                                                    style={{ borderColor: C.borderLight, backgroundColor: C.bgAlt, color: C.body }}>
                                                    {progData.generated_python}
                                                </pre>
                                            )}
                                        </div>
                                    )}
                                </Section>
                            );
                        })}

                        {/* Reset */}
                        <div className="pt-8">
                            <button
                                onClick={handleReset}
                                className="flex items-center gap-2 px-8 py-3 border text-[10px] uppercase tracking-[0.12em] transition-all duration-200 hover:opacity-80 rounded-sm"
                                style={{ borderColor: C.border, color: C.faint }}
                            >
                                <RefreshCw size={13} strokeWidth={1.5} />
                                New Analysis
                            </button>
                        </div>
                    </div>
                );
            })()}

            {showChat && result && (
                    <ExplanationChat
                        cobolContext={cobolCode}
                        pythonContext={result.generated_python || ''}
                        onClose={() => setShowChat(false)}
                    />
                )}
        </div>
    );
};

export default Engine;
