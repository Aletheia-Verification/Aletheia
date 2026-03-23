import { useState, useEffect, useMemo, useCallback } from 'react';
import {
    Lock,
    Download,
    ChevronUp,
    ChevronDown,
    ChevronLeft,
    ChevronRight,
    CheckCircle,
    AlertTriangle,
    ArrowRight,
    Search,
} from 'lucide-react';
import { apiUrl } from '../config/api';
import { generateForensicPDF, generateVaultExportPDF } from '../utils/pdfExport';
import { useColors, LIGHT } from '../hooks/useColors';

// ── Date formatter ───────────────────────────────────────────────────
const formatDate = (iso) => {
    if (!iso) return '—';
    const d = new Date(iso);
    return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit', timeZone: 'UTC', timeZoneName: 'short',
    }).format(d);
};

// ── Sortable column header ───────────────────────────────────────────
const SortHeader = ({ label, sortKey: sk, currentKey, currentDir, onSort, C }) => {
    if (!C) C = LIGHT;
    const active = currentKey === sk;
    return (
        <th
            className="px-4 py-3 cursor-pointer select-none text-left"
            onClick={() => onSort(sk)}
        >
            <span className="inline-flex items-center gap-1 text-[10px] font-semibold uppercase tracking-[0.1em]"
                style={{ color: active ? C.navy : C.faint }}
            >
                {label}
                {active && (currentDir === 'asc'
                    ? <ChevronUp size={12} />
                    : <ChevronDown size={12} />
                )}
            </span>
        </th>
    );
};

// ── Column header (non-sortable) ─────────────────────────────────────
const ColHeader = ({ label, C: _C }) => {
    const C = _C || LIGHT;
    return (
        <th className="px-4 py-3 text-center">
            <span className="text-[10px] font-semibold uppercase tracking-[0.1em]" style={{ color: C.faint }}>
                {label}
            </span>
        </th>
    );
};

// ═════════════════════════════════════════════════════════════════════
// VAULT COMPONENT
// ═════════════════════════════════════════════════════════════════════

const Vault = ({ onNavigate }) => {
    const C = useColors() || LIGHT;
    const [records, setRecords] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [sortKey, setSortKey] = useState('timestamp');
    const [sortDir, setSortDir] = useState('desc');
    const [page, setPage] = useState(1);
    const [search, setSearch] = useState('');
    const PAGE_SIZE = 50;

    // ── Fetch records ────────────────────────────────────────────────
    const fetchRecords = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const token = localStorage.getItem('alethia_token');
            const res = await fetch(apiUrl('/vault/list'), {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            setRecords(data.records || []);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { fetchRecords(); }, [fetchRecords]);

    // ── Sorted records ───────────────────────────────────────────────
    const sorted = useMemo(() => {
        const arr = [...records];
        arr.sort((a, b) => {
            let va = a[sortKey], vb = b[sortKey];
            if (sortKey === 'timestamp') {
                va = new Date(va || 0).getTime();
                vb = new Date(vb || 0).getTime();
            }
            if (typeof va === 'string') va = va.toLowerCase();
            if (typeof vb === 'string') vb = vb.toLowerCase();
            if (va < vb) return sortDir === 'asc' ? -1 : 1;
            if (va > vb) return sortDir === 'asc' ? 1 : -1;
            return 0;
        });
        return arr;
    }, [records, sortKey, sortDir]);

    // ── Filtered + paginated records ─────────────────────────────────
    const filtered = useMemo(() => {
        if (!search.trim()) return sorted;
        const q = search.toLowerCase();
        return sorted.filter(r => (r.filename || '').toLowerCase().includes(q));
    }, [sorted, search]);

    const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    const paged = useMemo(() => {
        const start = (page - 1) * PAGE_SIZE;
        return filtered.slice(start, start + PAGE_SIZE);
    }, [filtered, page, PAGE_SIZE]);

    // Reset page when search changes
    useEffect(() => { setPage(1); }, [search]);

    // ── Sort handler ─────────────────────────────────────────────────
    const handleSort = (key) => {
        if (sortKey === key) {
            setSortDir(d => d === 'asc' ? 'desc' : 'asc');
        } else {
            setSortKey(key);
            setSortDir('desc');
        }
    };

    // ── Export all as PDF ────────────────────────────────────────────
    const handleExport = () => {
        generateVaultExportPDF(records);
    };

    // ── Export single record as PDF ─────────────────────────────────
    const handleExportRecord = async (record) => {
        try {
            const token = localStorage.getItem('alethia_token');
            const res = await fetch(apiUrl(`/vault/record/${record.id}`), {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            let report = {};
            try { report = JSON.parse(data.full_report_json || '{}'); } catch { /* empty */ }
            const v = report.verification || {};
            generateForensicPDF({
                filename: data.filename,
                date: formatDate(data.timestamp),
                analyst: localStorage.getItem('corporate_id') || 'Unknown',
                coverage: data.verification_status || 'N/A',
                summary: data.executive_summary || v.executive_summary || '',
                cobolCode: report.parser_output?.raw_cobol || '(not stored)',
                pythonCode: data.generated_python || '',
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
                signature: data.signature ? {
                    signature: data.signature,
                    public_key_fingerprint: data.public_key_fp,
                    algorithm: 'RSA-PSS-SHA256',
                    verification_chain: (() => { try { return JSON.parse(data.verification_chain || '{}'); } catch { return {}; } })(),
                } : null,
            });
        } catch (err) {
            if (import.meta.env.DEV) console.error('Export failed:', err);
        }
    };

    // ═════════════════════════════════════════════════════════════════
    // RENDER
    // ═════════════════════════════════════════════════════════════════

    return (
        <div className="p-12 max-w-[1400px] mx-auto bg-white min-h-screen">

            {/* ── Header ─────────────────────────────────────────── */}
            <div className="flex justify-between items-end mb-8">
                <div className="flex items-center gap-4">
                    {onNavigate && (
                        <button
                            onClick={() => onNavigate('engine')}
                            className="flex items-center justify-center w-8 h-8 border rounded-sm hover:opacity-80"
                            style={{ borderColor: C.border, color: C.faint }}
                            title="Back to Engine"
                        >
                            <ChevronLeft size={16} strokeWidth={1.5} />
                        </button>
                    )}
                    <div className="space-y-1">
                        <div className="flex items-center gap-3">
                            <Lock size={18} strokeWidth={1.5} style={{ color: C.navy }} />
                            <h1 className="text-lg font-medium tracking-[0.2em] uppercase" style={{ color: C.text }}>
                                The Vault
                            </h1>
                        </div>
                        <p className="text-[11px] tracking-[0.15em] uppercase" style={{ color: C.faint }}>
                            Behavioral Verification Trail
                        </p>
                    </div>
                </div>
                {records.length > 0 && (
                    <button
                        onClick={handleExport}
                        className="flex items-center gap-2 px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] rounded-sm hover:opacity-80"
                        style={{ backgroundColor: C.navy, color: '#FFFFFF' }}
                    >
                        <Download size={14} strokeWidth={1.5} />
                        Export All (PDF)
                    </button>
                )}
            </div>

            {/* ── Search Box ─────────────────────────────────────── */}
            {!loading && !error && records.length > 0 && (
                <div className="relative mb-4">
                    <Search size={14} strokeWidth={1.5} style={{ color: C.faint }}
                        className="absolute left-3 top-1/2 -translate-y-1/2" />
                    <input
                        type="text"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Filter by filename..."
                        className="w-full pl-9 pr-4 py-2.5 text-[12px] rounded-sm border outline-none focus:border-gray-400"
                        style={{ borderColor: C.border, color: C.text, backgroundColor: C.bg }}
                    />
                </div>
            )}

            {/* ── Loading ────────────────────────────────────────── */}
            {loading && (
                <div className="flex items-center justify-center py-24">
                    <div className="text-center space-y-3">
                        <div className="inline-block w-8 h-8 border-2 rounded-full animate-spin"
                            style={{ borderColor: C.border, borderTopColor: C.navy }} />
                        <p className="text-[11px] tracking-wider uppercase" style={{ color: C.faint }}>
                            Loading vault records...
                        </p>
                    </div>
                </div>
            )}

            {/* ── Error ──────────────────────────────────────────── */}
            {error && (
                <div className="text-center py-16 space-y-3">
                    <AlertTriangle size={24} style={{ color: C.amber }} className="mx-auto" />
                    <p className="text-[12px]" style={{ color: C.body }}>Failed to load vault: {error}</p>
                    <button onClick={fetchRecords}
                        className="text-[11px] uppercase tracking-wider px-4 py-2 rounded-sm border"
                        style={{ color: C.navy, borderColor: C.border }}>
                        Retry
                    </button>
                </div>
            )}

            {/* ── Empty State ────────────────────────────────────── */}
            {!loading && !error && records.length === 0 && (
                <div className="text-center py-24 space-y-6">
                    <div className="w-16 h-16 mx-auto flex items-center justify-center border rounded-sm"
                        style={{ borderColor: C.border }}>
                        <Lock size={28} strokeWidth={1} style={{ color: C.faint }} />
                    </div>
                    <div className="space-y-2">
                        <p className="text-[13px] font-medium" style={{ color: C.text }}>
                            No analyses yet
                        </p>
                        <p className="text-[11px] tracking-wider" style={{ color: C.faint }}>
                            Use The Engine to verify your first COBOL program.
                        </p>
                    </div>
                    {onNavigate && (
                        <button
                            onClick={() => onNavigate('engine')}
                            className="inline-flex items-center gap-2 px-6 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] rounded-sm"
                            style={{ backgroundColor: C.navy, color: '#FFFFFF' }}
                        >
                            Go to The Engine
                            <ArrowRight size={14} strokeWidth={1.5} />
                        </button>
                    )}
                </div>
            )}

            {/* ── Table ──────────────────────────────────────────── */}
            {!loading && !error && records.length > 0 && (<>
                <div className="border rounded-sm overflow-hidden" style={{ borderColor: C.border }}>
                    <table className="w-full border-collapse">
                        <thead>
                            <tr style={{ backgroundColor: C.bgAlt, borderBottom: `1px solid ${C.border}` }}>
                                <SortHeader label="Date" sortKey="timestamp" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} C={C} />
                                <SortHeader label="Filename" sortKey="filename" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} C={C} />
                                <SortHeader label="Verdict" sortKey="verification_status" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} C={C} />
                                <ColHeader label="" C={C} />
                            </tr>
                        </thead>
                        <tbody>
                            {paged.map((r, i) => {
                                const verified = r.verification_status === 'VERIFIED';
                                return (
                                    <tr
                                        key={r.id}
                                        style={{
                                            backgroundColor: i % 2 === 0 ? C.bg : C.bgAlt,
                                            borderBottom: `1px solid ${C.border}`,
                                        }}
                                    >
                                        <td className="px-4 py-3 text-[11px] font-mono whitespace-nowrap" style={{ color: C.body }}>
                                            {formatDate(r.timestamp)}
                                        </td>
                                        <td className="px-4 py-3 text-[13px] font-medium" style={{ color: C.text }}>
                                            {r.filename}
                                        </td>
                                        <td className="px-4 py-3">
                                            <span
                                                className="inline-flex items-center gap-1.5 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.08em] rounded-sm"
                                                style={{
                                                    color: verified ? '#2E7D32' : C.amber,
                                                    backgroundColor: verified ? '#E8F5E9' : C.amberBg,
                                                    border: `1px solid ${verified ? '#C8E6C9' : C.amberBorder}`,
                                                }}
                                            >
                                                {verified
                                                    ? <CheckCircle size={11} strokeWidth={2} />
                                                    : <AlertTriangle size={11} strokeWidth={2} />
                                                }
                                                {verified ? 'Verified' : 'Manual Review'}
                                            </span>
                                        </td>
                                        <td className="px-4 py-3 text-right">
                                            <button
                                                onClick={() => handleExportRecord(r)}
                                                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.1em] rounded-sm border hover:opacity-80"
                                                style={{ color: C.navy, borderColor: C.border }}
                                            >
                                                <Download size={12} strokeWidth={1.5} />
                                                PDF
                                            </button>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>

                {/* ── Pagination ──────────────────────────────────── */}
                {totalPages > 1 && (
                    <div className="flex items-center justify-between mt-4 px-2">
                        <span className="text-[11px]" style={{ color: C.faint }}>
                            Showing {((page - 1) * PAGE_SIZE) + 1}–{Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length} records
                        </span>
                        <div className="flex items-center gap-2">
                            <button
                                onClick={() => setPage(p => Math.max(1, p - 1))}
                                disabled={page === 1}
                                className="flex items-center gap-1 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider rounded-sm border disabled:opacity-40 hover:opacity-80"
                                style={{ color: C.navy, borderColor: C.border }}
                            >
                                <ChevronLeft size={12} strokeWidth={1.5} />
                                Previous
                            </button>
                            <span className="text-[11px] font-mono px-2" style={{ color: C.body }}>
                                {page} / {totalPages}
                            </span>
                            <button
                                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                                disabled={page === totalPages}
                                className="flex items-center gap-1 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider rounded-sm border disabled:opacity-40 hover:opacity-80"
                                style={{ color: C.navy, borderColor: C.border }}
                            >
                                Next
                                <ChevronRight size={12} strokeWidth={1.5} />
                            </button>
                        </div>
                    </div>
                )}
            </>)}
        </div>
    );
};

export default Vault;
