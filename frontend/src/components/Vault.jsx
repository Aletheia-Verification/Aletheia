import { useState, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    FileCode,
    ChevronDown,
    Search,
    MessageSquare,
    Copy,
    Download,
    RefreshCw,
    CheckCircle,
    ShieldCheck,
    AlertTriangle
} from 'lucide-react';
import ExplanationChat from './ExplanationChat';
import { apiUrl } from '../config/api';
import { formatVaultDate } from '../utils/dateFormat';
import { generateForensicPDF } from '../utils/pdfExport';

const ConfidenceBadge = ({ level }) => {
    if (!level) return null;
    const cfg = {
        VERIFIED: 'text-green-400 bg-green-500/10 border-green-500/30',
        PROBABLE: 'text-amber-400 bg-amber-500/10 border-amber-500/30',
        UNCERTAIN: 'text-yellow-400 bg-yellow-500/10 border-yellow-500/30',
        UNRELIABLE: 'text-red-400 bg-red-500/10 border-red-500/30',
    };
    return (
        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[9px] font-mono uppercase tracking-wider border ${cfg[level] || cfg.UNCERTAIN}`}>
            {level}
        </span>
    );
};

// Fallback mock data when API isn't available
const MOCK_CONVERSIONS = [
    {
        id: '1',
        filename: 'INTR-CALC-3270.cbl',
        created_at: '2026-01-28T14:32:00Z',
        conversion_type: 'COBOL \u2192 Python 3.12',
        cobol_source: `       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTR-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRINCIPAL    PIC 9(9)V99.
       01 WS-RATE         PIC 9(2)V9(4).
       01 WS-INTEREST     PIC 9(9)V99.`,
        python_output: `from decimal import Decimal, ROUND_HALF_UP

def calculate_interest(principal: Decimal, rate: Decimal) -> Decimal:
    """Calculate interest with COBOL-equivalent precision."""
    interest = principal * rate
    return interest.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)`
    },
    {
        id: '2',
        filename: 'ACCT-BALANCE-2100.cbl',
        created_at: '2026-01-27T09:15:00Z',
        conversion_type: 'COBOL \u2192 Python 3.12',
        cobol_source: `       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-BAL.`,
        python_output: `from decimal import Decimal

def get_account_balance(account_id: str) -> Decimal:
    """Retrieve account balance."""
    pass`
    },
    {
        id: '3',
        filename: 'LOAN-PROC-1985.cbl',
        created_at: '2026-01-25T16:48:00Z',
        conversion_type: 'COBOL \u2192 Python 3.12',
        cobol_source: '',
        python_output: ''
    }
];

const Vault = () => {
    const [conversions, setConversions] = useState([]);
    const [expandedId, setExpandedId] = useState(null);
    const [showChat, setShowChat] = useState(false);
    const [selectedConversion, setSelectedConversion] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [filterBy, setFilterBy] = useState('all'); // 'all' | 'passed' | 'review'
    const [sortBy, setSortBy] = useState('date-desc'); // 'date-desc' | 'date-asc' | 'name' | 'confidence'
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchConversions = async () => {
            try {
                const token = localStorage.getItem('alethia_token');
                const response = await fetch(apiUrl('/vault'), {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                if (response.ok) {
                    const data = await response.json();
                    const sessions = data.analyses || [];
                    if (sessions.length > 0) {
                        setConversions(sessions);
                    } else {
                        setConversions(MOCK_CONVERSIONS);
                    }
                } else {
                    setConversions(MOCK_CONVERSIONS);
                }
            } catch {
                setConversions(MOCK_CONVERSIONS);
            } finally {
                setLoading(false);
            }
        };
        fetchConversions();
    }, []);

    const handleToggleExpand = (id) => {
        setExpandedId(expandedId === id ? null : id);
    };

    const handleOpenChat = (conversion) => {
        setSelectedConversion(conversion);
        setShowChat(true);
    };

    const handleExportPDF = (conversion) => {
        generateForensicPDF({
            filename: conversion.filename || 'analysis.cbl',
            date: conversion.created_at ? new Date(conversion.created_at).toLocaleString() : new Date().toLocaleString(),
            analyst: localStorage.getItem('corporate_id') || 'Unknown',
            confidence: conversion.audit?.level || 'N/A',
            summary: conversion.executive_summary || conversion.executive_explanation || '',
            cobolCode: conversion.cobol_source || '',
            pythonCode: conversion.python_output || conversion.python_implementation || '',
            mathBreakdown: conversion.mathematical_breakdown || '',
            findings: conversion.findings || [],
            uncertainties: conversion.uncertainties || [],
            audit: conversion.audit || null,
        });
    };

    // Stats calculation
    const stats = useMemo(() => {
        const total = conversions.length;
        const passed = conversions.filter(c => c.audit?.passed || c.audit?.level === 'VERIFIED').length;
        const review = total - passed;
        const thisWeek = conversions.filter(c => {
            if (!c.created_at) return false;
            const date = new Date(c.created_at);
            const weekAgo = new Date();
            weekAgo.setDate(weekAgo.getDate() - 7);
            return date >= weekAgo;
        }).length;
        return { total, passed, review, thisWeek };
    }, [conversions]);

    // Filtered & sorted conversions
    const filteredConversions = useMemo(() => {
        let result = [...conversions];

        // Filter
        if (filterBy === 'passed') {
            result = result.filter(c => c.audit?.passed || c.audit?.level === 'VERIFIED');
        } else if (filterBy === 'review') {
            result = result.filter(c => !(c.audit?.passed || c.audit?.level === 'VERIFIED'));
        }

        // Search
        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            result = result.filter(c =>
                (c.filename || '').toLowerCase().includes(query) ||
                (c.executive_summary || '').toLowerCase().includes(query) ||
                (c.executive_explanation || '').toLowerCase().includes(query)
            );
        }

        // Sort
        switch (sortBy) {
            case 'date-desc':
                result.sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime());
                break;
            case 'date-asc':
                result.sort((a, b) => new Date(a.created_at || 0).getTime() - new Date(b.created_at || 0).getTime());
                break;
            case 'name':
                result.sort((a, b) => (a.filename || '').localeCompare(b.filename || ''));
                break;
            case 'confidence':
                result.sort((a, b) => {
                    const confA = parseFloat(a.audit?.confidence || 0);
                    const confB = parseFloat(b.audit?.confidence || 0);
                    return confB - confA;
                });
                break;
        }

        return result;
    }, [conversions, filterBy, searchQuery, sortBy]);

    if (loading) {
        return (
            <div className="p-12 flex items-center justify-center min-h-[50vh]">
                <div className="w-8 h-8 border-2 border-primary/20 border-t-primary rounded-full animate-spin" />
            </div>
        );
    }

    return (
        <div className="p-12 max-w-[1000px] mx-auto">
            {/* Header */}
            <header className="border-b border-border pb-8 mb-8">
                <div className="flex justify-between items-end mb-8">
                    <div className="space-y-2">
                        <h1 className="text-2xl font-mono font-bold tracking-[0.2em] text-text uppercase">
                            The Vault
                        </h1>
                        <p className="text-[10px] text-text-dim uppercase tracking-[0.3em]">
                            Analysis Repository
                        </p>
                    </div>
                    <div className="flex items-center gap-3">
                        {/* Search */}
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-text-dim" size={14} />
                            <input
                                type="text"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                placeholder="Search..."
                                className="bg-surface border border-border pl-10 pr-4 py-2.5 text-[11px] font-mono tracking-wider
                                         focus:border-primary/50 outline-none transition-all w-56"
                            />
                        </div>
                        {/* Filter */}
                        <select
                            value={filterBy}
                            onChange={(e) => setFilterBy(e.target.value)}
                            className="bg-surface border border-border px-4 py-2.5 text-[11px] font-mono tracking-wider
                                     focus:border-primary/50 outline-none transition-all cursor-pointer"
                        >
                            <option value="all">All Analyses</option>
                            <option value="passed">✓ Passed Only</option>
                            <option value="review">⚠ Needs Review</option>
                        </select>
                        {/* Sort */}
                        <select
                            value={sortBy}
                            onChange={(e) => setSortBy(e.target.value)}
                            className="bg-surface border border-border px-4 py-2.5 text-[11px] font-mono tracking-wider
                                     focus:border-primary/50 outline-none transition-all cursor-pointer"
                        >
                            <option value="date-desc">Newest First</option>
                            <option value="date-asc">Oldest First</option>
                            <option value="name">By Name</option>
                            <option value="confidence">By Confidence</option>
                        </select>
                    </div>
                </div>

                {/* Stats Bar */}
                <div className="flex gap-6 p-5 bg-surface/40 border border-border">
                    <div className="flex flex-col items-center min-w-[80px]">
                        <span className="text-2xl font-bold text-text">{stats.total}</span>
                        <span className="text-[10px] font-mono uppercase tracking-wider text-text-dim">Total</span>
                    </div>
                    <div className="flex flex-col items-center min-w-[80px]">
                        <span className="text-2xl font-bold" style={{color: 'var(--color-success-text)'}}>{stats.passed}</span>
                        <span className="text-[10px] font-mono uppercase tracking-wider text-text-dim">Passed</span>
                    </div>
                    <div className="flex flex-col items-center min-w-[80px]">
                        <span className="text-2xl font-bold" style={{color: 'var(--color-warning-text)'}}>{stats.review}</span>
                        <span className="text-[10px] font-mono uppercase tracking-wider text-text-dim">Review</span>
                    </div>
                    <div className="flex flex-col items-center min-w-[80px]">
                        <span className="text-2xl font-bold text-text">{stats.thisWeek}</span>
                        <span className="text-[10px] font-mono uppercase tracking-wider text-text-dim">This Week</span>
                    </div>
                </div>
            </header>

            {/* Conversions List */}
            <div className="space-y-4">
                {filteredConversions.length === 0 ? (
                    <div className="py-24 text-center space-y-4">
                        <FileCode size={32} className="mx-auto text-text-dim/20" />
                        <p className="text-[10px] font-mono uppercase tracking-[0.3em] text-text-dim/50">
                            {searchQuery ? 'No matching files' : 'No conversions stored yet'}
                        </p>
                        {!searchQuery && (
                            <p className="text-[9px] font-mono text-text-dim/30 uppercase tracking-wider">
                                Run an analysis in The Engine to populate your vault
                            </p>
                        )}
                    </div>
                ) : (
                    filteredConversions.map((conversion, index) => (
                        <motion.div
                            key={conversion.id}
                            initial={{ opacity: 0, y: 12 }}
                            animate={{ opacity: 1, y: 0 }}
                            whileHover={{ y: -2 }}
                            transition={{ duration: 0.3, delay: index * 0.06 }}
                            className="border border-border bg-surface/30 hover:border-primary/30 transition-colors"
                        >
                            {/* Item Header */}
                            <div
                                onClick={() => handleToggleExpand(conversion.id)}
                                className="flex items-center justify-between p-5 cursor-pointer group"
                            >
                                <div className="flex items-center gap-4">
                                    <FileCode size={18} className="text-primary/70" />
                                    <div>
                                        <div className="text-sm font-mono font-medium text-text tracking-wide">
                                            {conversion.filename}
                                        </div>
                                        <div className="flex items-center gap-3 mt-1">
                                            <span className="text-[10px] font-mono text-text-dim uppercase tracking-wider">
                                                {conversion.conversion_type || 'COBOL \u2192 Python'}
                                            </span>
                                            <span className="text-text-dim/30">&middot;</span>
                                            <span className="text-[10px] font-mono text-text-dim/70">
                                                {formatVaultDate(conversion.created_at, 'relative')}
                                            </span>
                                            {conversion.audit?.level && (
                                                <>
                                                    <span className="text-text-dim/30">&middot;</span>
                                                    <ConfidenceBadge level={conversion.audit.level} />
                                                </>
                                            )}
                                        </div>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3">
                                    {/* Action buttons */}
                                    <button
                                        onClick={(e) => { e.stopPropagation(); handleOpenChat(conversion); }}
                                        className="p-2 text-text-dim hover:text-primary transition-colors"
                                        title="Ask about this conversion"
                                    >
                                        <MessageSquare size={14} />
                                    </button>
                                    <button
                                        onClick={(e) => { e.stopPropagation(); handleExportPDF(conversion); }}
                                        className="p-2 text-text-dim hover:text-primary transition-colors"
                                        title="Export PDF"
                                    >
                                        <Download size={14} />
                                    </button>
                                    <ChevronDown
                                        size={16}
                                        className={`text-text-dim transition-transform duration-200 ${expandedId === conversion.id ? 'rotate-180' : ''}`}
                                    />
                                </div>
                            </div>

                            {/* Expanded Content */}
                            <AnimatePresence>
                            {expandedId === conversion.id && (() => {
                                const executiveText =
                                    (typeof conversion.executive_summary === 'string' && conversion.executive_summary.trim()) ||
                                    (typeof conversion.executive_explanation === 'string' && conversion.executive_explanation.trim()) ||
                                    '';

                                const logicalRaw = conversion.logical_flow_summary;
                                const logicalSteps = Array.isArray(logicalRaw)
                                    ? logicalRaw.filter((step) => typeof step === 'string' && step.trim())
                                    : typeof logicalRaw === 'string'
                                        ? logicalRaw
                                            .split('\n')
                                            .map((line) => line.trim())
                                            .filter((line) => line)
                                        : [];

                                const pythonSource =
                                    (typeof conversion.python_output === 'string' && conversion.python_output) ||
                                    (typeof conversion.python_implementation === 'string' && conversion.python_implementation) ||
                                    '';

                                const commentaryRaw = conversion.code_commentary;
                                const commentaryBlocks = Array.isArray(commentaryRaw)
                                    ? commentaryRaw.filter((block) => typeof block === 'string' && block.trim())
                                    : typeof commentaryRaw === 'string' && commentaryRaw.trim()
                                        ? [commentaryRaw]
                                        : [];

                                const hasExecutive = Boolean(executiveText);
                                const hasLogical = logicalSteps.length > 0;
                                const hasPython = Boolean(pythonSource);
                                const hasCommentary = commentaryBlocks.length > 0;

                                if (!hasExecutive && !hasLogical && !hasPython && !hasCommentary) {
                                    return null;
                                }

                                const handleCopyPython = () => {
                                    if (!hasPython) return;
                                    navigator.clipboard.writeText(pythonSource);
                                };

                                return (
                                    <motion.div
                                        key={`expanded-${conversion.id}`}
                                        initial={{ height: 0, opacity: 0 }}
                                        animate={{ height: 'auto', opacity: 1 }}
                                        exit={{ height: 0, opacity: 0 }}
                                        transition={{ duration: 0.25, ease: [0.33, 1, 0.68, 1] }}
                                        className="overflow-hidden"
                                    >
                                    <div className="px-5 pb-6 pt-4 border-t border-border/50 bg-background/40">
                                        {/* Date detail */}
                                        <div className="mb-4 text-[9px] font-mono text-text-dim/50 uppercase tracking-wider">
                                            {formatVaultDate(conversion.created_at, 'full')}
                                        </div>

                                        {/* 1. Executive Explanation */}
                                        {hasExecutive && (
                                            <section className="space-y-2">
                                                <h3 className="text-[10px] font-mono uppercase tracking-[0.2em] text-text-dim">
                                                    Executive Explanation
                                                </h3>
                                                <p className="text-sm text-text leading-relaxed whitespace-pre-wrap">
                                                    {executiveText}
                                                </p>
                                            </section>
                                        )}

                                        {/* 2. Logical Flow Summary */}
                                        {hasLogical && (
                                            <section className={`space-y-2 ${hasExecutive ? 'mt-6 pt-6 border-t border-border/40' : ''}`}>
                                                <h3 className="text-[10px] font-mono uppercase tracking-[0.2em] text-text-dim">
                                                    Logical Flow Summary
                                                </h3>
                                                <ol className="list-decimal ml-5 space-y-1 text-sm text-text leading-relaxed">
                                                    {logicalSteps.map((step, index) => (
                                                        <li key={index} className="whitespace-pre-wrap">
                                                            {step}
                                                        </li>
                                                    ))}
                                                </ol>
                                            </section>
                                        )}

                                        {/* 3. Python Translation */}
                                        {hasPython && (
                                            <section
                                                className={`space-y-3 ${
                                                    hasExecutive || hasLogical ? 'mt-6 pt-6 border-t border-border/40' : ''
                                                }`}
                                            >
                                                <div className="flex items-center justify-between">
                                                    <h3 className="text-[10px] font-mono uppercase tracking-[0.2em] text-text-dim">
                                                        Python Translation
                                                    </h3>
                                                    <button
                                                        type="button"
                                                        onClick={handleCopyPython}
                                                        className="inline-flex items-center gap-1 px-3 py-1.5 text-[9px] font-mono uppercase tracking-widest border border-border hover:border-primary/60 hover:text-primary transition-colors"
                                                    >
                                                        <Copy size={12} />
                                                        Copy Python
                                                    </button>
                                                </div>
                                                <pre className="bg-background border border-border p-4 text-[11px] font-mono text-text/80 whitespace-pre-wrap break-words">
                                                    <code>{pythonSource}</code>
                                                </pre>
                                            </section>
                                        )}

                                        {/* 4. Code Commentary */}
                                        {hasCommentary && (
                                            <section className="mt-6 pt-6 border-t border-border/40 space-y-2">
                                                <h3 className="text-[10px] font-mono uppercase tracking-[0.2em] text-text-dim">
                                                    Code Commentary
                                                </h3>
                                                <div className="space-y-2 text-sm text-text leading-relaxed">
                                                    {commentaryBlocks.map((block, index) => (
                                                        <p key={index} className="whitespace-pre-wrap">
                                                            {block}
                                                        </p>
                                                    ))}
                                                </div>
                                            </section>
                                        )}
                                    </div>
                                    </motion.div>
                                );
                            })()}
                            </AnimatePresence>
                        </motion.div>
                    ))
                )}
            </div>

            {/* Footer */}
            <footer className="mt-16 pt-8 border-t border-border flex justify-between items-center text-[9px] font-mono uppercase tracking-[0.2em] text-text-dim/40">
                <div className="flex gap-8">
                    <span>SOC-2 Type II</span>
                    <span>PCI-DSS</span>
                    <span>GDPR</span>
                </div>
                <div>
                    Institutional Access Only
                </div>
            </footer>

            {/* Contextual Chat */}
            <AnimatePresence>
                {showChat && selectedConversion && (
                    <ExplanationChat
                        cobolContext={selectedConversion.cobol_source || ''}
                        pythonContext={selectedConversion.python_output || selectedConversion.python_implementation || ''}
                        context="vault"
                        onClose={() => {
                            setShowChat(false);
                            setSelectedConversion(null);
                        }}
                    />
                )}
            </AnimatePresence>
        </div>
    );
};

export default Vault;
