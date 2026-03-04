import { useState, useEffect, useMemo, useCallback } from 'react';
import {
    Lock,
    Download,
    Eye,
    Trash2,
    Copy,
    X,
    ChevronUp,
    ChevronDown,
    FileCode,
    CheckCircle,
    AlertTriangle,
    ArrowRight,
    ShieldCheck,
} from 'lucide-react';
import { apiUrl } from '../config/api';
import { generateForensicPDF, generateVaultExportPDF } from '../utils/pdfExport';

// ── Colors (same as Engine.jsx) ──────────────────────────────────────
const C = {
    navy: '#1B2A4A',
    text: '#1A1A2E',
    body: '#2D2D3D',
    muted: '#5A5A6E',
    faint: '#6B7280',
    border: '#E5E7EB',
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
    gold: '#C9A84C',
};

// ── Date formatter ───────────────────────────────────────────────────
const formatDate = (iso) => {
    if (!iso) return '—';
    const d = new Date(iso);
    return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit', timeZone: 'UTC', timeZoneName: 'short',
    }).format(d);
};

// ── Status badge ─────────────────────────────────────────────────────
const StatusBadge = ({ status }) => {
    const verified = status === 'VERIFIED';
    return (
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
    );
};

// ── Sortable column header ───────────────────────────────────────────
const SortHeader = ({ label, sortKey: sk, currentKey, currentDir, onSort }) => {
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
const ColHeader = ({ label }) => (
    <th className="px-4 py-3 text-center">
        <span className="text-[10px] font-semibold uppercase tracking-[0.1em]" style={{ color: C.faint }}>
            {label}
        </span>
    </th>
);

// ═════════════════════════════════════════════════════════════════════
// VAULT COMPONENT
// ═════════════════════════════════════════════════════════════════════

const Vault = ({ onNavigate }) => {
    const [records, setRecords] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [sortKey, setSortKey] = useState('timestamp');
    const [sortDir, setSortDir] = useState('desc');
    const [selectedRecord, setSelectedRecord] = useState(null);
    const [detailLoading, setDetailLoading] = useState(false);
    const [deleteConfirm, setDeleteConfirm] = useState(null);
    const [copySuccess, setCopySuccess] = useState(false);
    const [verifyResult, setVerifyResult] = useState(null);
    const [verifying, setVerifying] = useState(false);

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

    // ── Stats ────────────────────────────────────────────────────────
    const stats = useMemo(() => {
        const total = records.length;
        const verified = records.filter(r => r.verification_status === 'VERIFIED').length;
        const review = total - verified;
        const criticalRisks = records.reduce((sum, r) => sum + (r.arithmetic_critical || 0), 0);
        return { total, verified, review, criticalRisks };
    }, [records]);

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

    // ── Sort handler ─────────────────────────────────────────────────
    const handleSort = (key) => {
        if (sortKey === key) {
            setSortDir(d => d === 'asc' ? 'desc' : 'asc');
        } else {
            setSortKey(key);
            setSortDir('desc');
        }
    };

    // ── View detail ──────────────────────────────────────────────────
    const handleView = async (id) => {
        setDetailLoading(true);
        try {
            const token = localStorage.getItem('alethia_token');
            const res = await fetch(apiUrl(`/vault/record/${id}`), {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            setSelectedRecord(data);
            setVerifyResult(null);
        } catch (err) {
            console.error('Failed to load record:', err);
        } finally {
            setDetailLoading(false);
        }
    };

    // ── Delete ───────────────────────────────────────────────────────
    const handleDelete = async (id) => {
        try {
            const token = localStorage.getItem('alethia_token');
            await fetch(apiUrl(`/vault/record/${id}`), {
                method: 'DELETE',
                headers: { Authorization: `Bearer ${token}` },
            });
            setDeleteConfirm(null);
            setRecords(prev => prev.filter(r => r.id !== id));
        } catch (err) {
            console.error('Delete failed:', err);
        }
    };

    // ── Export all as PDF ────────────────────────────────────────────
    const handleExport = () => {
        generateVaultExportPDF(records);
    };

    // ── Copy python ──────────────────────────────────────────────────
    const handleCopyPython = (code) => {
        if (!code) return;
        navigator.clipboard.writeText(code);
        setCopySuccess(true);
        setTimeout(() => setCopySuccess(false), 2000);
    };

    // ── Verify signature ─────────────────────────────────────────────
    const handleVerify = async (recordId) => {
        setVerifying(true);
        setVerifyResult(null);
        try {
            const token = localStorage.getItem('alethia_token');
            const res = await fetch(apiUrl('/verify'), {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ record_id: recordId }),
            });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            setVerifyResult(data);
        } catch (err) {
            setVerifyResult({ valid: false, details: err.message });
        } finally {
            setVerifying(false);
        }
    };

    // ── Re-export PDF ────────────────────────────────────────────────
    const handleReexportPDF = (record) => {
        let report = {};
        try {
            report = JSON.parse(record.full_report_json || '{}');
        } catch { /* empty */ }
        const v = report.verification || {};
        generateForensicPDF({
            filename: record.filename,
            date: formatDate(record.timestamp),
            analyst: localStorage.getItem('corporate_id') || 'Unknown',
            confidence: record.verification_status || 'N/A',
            summary: record.executive_summary || v.executive_summary || '',
            cobolCode: report.parser_output?.raw_cobol || '(not stored)',
            pythonCode: record.generated_python || '',
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
            signature: record.signature ? {
                signature: record.signature,
                public_key_fingerprint: record.public_key_fp,
                algorithm: 'RSA-PSS-SHA256',
                verification_chain: (() => { try { return JSON.parse(record.verification_chain || '{}'); } catch { return {}; } })(),
            } : null,
        });
    };

    // ═════════════════════════════════════════════════════════════════
    // RENDER
    // ═════════════════════════════════════════════════════════════════

    return (
        <div className="p-12 max-w-[1400px] mx-auto bg-white min-h-screen">

            {/* ── Header ─────────────────────────────────────────── */}
            <div className="flex justify-between items-end mb-8">
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
                {records.length > 0 && (
                    <button
                        onClick={handleExport}
                        className="flex items-center gap-2 px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] rounded-sm transition-all"
                        style={{ backgroundColor: C.navy, color: '#FFFFFF' }}
                    >
                        <Download size={14} strokeWidth={1.5} />
                        Export All (PDF)
                    </button>
                )}
            </div>

            {/* ── Stats Bar ──────────────────────────────────────── */}
            {!loading && records.length > 0 && (
                <div className="flex items-center gap-6 px-6 py-3.5 mb-8 rounded-sm border" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                    <span className="text-[12px]" style={{ color: C.body }}>
                        <strong style={{ color: C.text }}>{stats.total}</strong> Total Analyses
                    </span>
                    <span style={{ color: C.border }}>|</span>
                    <span className="text-[12px]" style={{ color: C.body }}>
                        <strong style={{ color: C.green }}>{stats.verified}</strong> Verified
                    </span>
                    <span style={{ color: C.border }}>|</span>
                    <span className="text-[12px]" style={{ color: C.body }}>
                        <strong style={{ color: C.amber }}>{stats.review}</strong> Requires Review
                    </span>
                    <span style={{ color: C.border }}>|</span>
                    <span className="text-[12px]" style={{ color: C.body }}>
                        <strong style={{ color: C.red }}>{stats.criticalRisks}</strong> Critical Risks Found
                    </span>
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
            {!loading && !error && records.length > 0 && (
                <div className="border rounded-sm overflow-hidden" style={{ borderColor: C.border }}>
                    <table className="w-full border-collapse">
                        <thead>
                            <tr style={{ backgroundColor: C.bgAlt, borderBottom: `1px solid ${C.border}` }}>
                                <SortHeader label="Date" sortKey="timestamp" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} />
                                <SortHeader label="Filename" sortKey="filename" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} />
                                <SortHeader label="Status" sortKey="verification_status" currentKey={sortKey} currentDir={sortDir} onSort={handleSort} />
                                <ColHeader label="Paras" />
                                <ColHeader label="Vars" />
                                <ColHeader label="COMP-3" />
                                <ColHeader label="Risks (S/W/C)" />
                                <ColHeader label="Flags" />
                                <ColHeader label="Checklist" />
                                <ColHeader label="Signed" />
                                <ColHeader label="Actions" />
                            </tr>
                        </thead>
                        <tbody>
                            {sorted.map((r, i) => (
                                <tr
                                    key={r.id}
                                    className="group transition-colors"
                                    style={{
                                        backgroundColor: i % 2 === 0 ? C.bg : C.bgAlt,
                                        borderBottom: `1px solid ${C.border}`,
                                    }}
                                >
                                    <td className="px-3 py-2 text-[11px] font-mono whitespace-nowrap" style={{ color: C.body }}>
                                        {formatDate(r.timestamp)}
                                    </td>
                                    <td className="px-3 py-2">
                                        <span className="flex items-center gap-2 text-[13px] font-medium" style={{ color: C.text }}>
                                            <FileCode size={13} strokeWidth={1.5} style={{ color: C.faint }} />
                                            {r.filename}
                                        </span>
                                    </td>
                                    <td className="px-3 py-2">
                                        <StatusBadge status={r.verification_status} />
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono" style={{ color: C.body }}>
                                        {r.paragraphs_count}
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono" style={{ color: C.body }}>
                                        {r.variables_count}
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono" style={{ color: C.body }}>
                                        {r.comp3_count}
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono whitespace-nowrap">
                                        <span style={{ color: C.green }}>{r.arithmetic_safe}</span>
                                        <span style={{ color: C.faint }}>/</span>
                                        <span style={{ color: C.amber }}>{r.arithmetic_warn}</span>
                                        <span style={{ color: C.faint }}>/</span>
                                        <span style={{ color: C.red }}>{r.arithmetic_critical}</span>
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono" style={{ color: r.human_review_flags > 0 ? C.amber : C.body }}>
                                        {r.human_review_flags}
                                    </td>
                                    <td className="px-3 py-2 text-center text-[13px] font-mono" style={{ color: C.body }}>
                                        <span style={{ color: r.checklist_pass === r.checklist_total ? C.green : C.amber }}>
                                            {r.checklist_pass}
                                        </span>
                                        /{r.checklist_total}
                                    </td>
                                    <td className="px-3 py-2 text-center">
                                        {r.signature ? (
                                            <ShieldCheck size={15} strokeWidth={1.5} style={{ color: C.green }} className="mx-auto" title="Cryptographically Signed" />
                                        ) : (
                                            <Lock size={14} strokeWidth={1.5} style={{ color: C.faint }} className="mx-auto" title="Not Signed" />
                                        )}
                                    </td>
                                    <td className="px-3 py-2">
                                        <div className="flex items-center justify-center gap-2">
                                            <button
                                                onClick={() => handleView(r.id)}
                                                className="p-1.5 rounded-sm transition-colors hover:bg-gray-100"
                                                title="View full report"
                                            >
                                                <Eye size={14} strokeWidth={1.5} style={{ color: C.navy }} />
                                            </button>
                                            <button
                                                onClick={() => setDeleteConfirm(r)}
                                                className="p-1.5 rounded-sm transition-colors hover:bg-red-50"
                                                title="Delete record"
                                            >
                                                <Trash2 size={14} strokeWidth={1.5} style={{ color: C.faint }} />
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {/* ── Delete Confirmation ────────────────────────────── */}
            {deleteConfirm && (
                <div
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm modal-backdrop"
                    onClick={() => setDeleteConfirm(null)}
                >
                    <div
                        className="bg-white p-8 max-w-md w-full mx-4 border shadow-lg rounded-sm fade-in"
                        style={{ borderColor: C.border }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <h3 className="text-[14px] font-semibold mb-2" style={{ color: C.text }}>
                            Delete Analysis Record?
                        </h3>
                        <p className="text-[12px] mb-6" style={{ color: C.body }}>
                            This will permanently remove the verification record for <strong>{deleteConfirm.filename}</strong>. This action cannot be undone.
                        </p>
                        <div className="flex justify-end gap-3">
                            <button
                                onClick={() => setDeleteConfirm(null)}
                                className="px-4 py-2 text-[11px] font-semibold uppercase tracking-wider rounded-sm border"
                                style={{ color: C.body, borderColor: C.border }}
                            >
                                Cancel
                            </button>
                            <button
                                onClick={() => handleDelete(deleteConfirm.id)}
                                className="px-4 py-2 text-[11px] font-semibold uppercase tracking-wider rounded-sm"
                                style={{ backgroundColor: C.red, color: '#FFFFFF' }}
                            >
                                Delete
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* ── Detail Modal ────────────────────────────────────── */}
            {selectedRecord && (
                <div
                    className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 backdrop-blur-sm overflow-y-auto py-8 modal-backdrop"
                    onClick={() => setSelectedRecord(null)}
                >
                    <div
                        className="bg-white w-full max-w-3xl mx-4 border shadow-xl rounded-sm fade-in"
                        style={{ borderColor: C.border }}
                        onClick={(e) => e.stopPropagation()}
                    >
                            {/* Modal Header */}
                            <div className="flex items-center justify-between px-8 py-5 border-b" style={{ borderColor: C.border }}>
                                <div className="flex items-center gap-4">
                                    <ShieldCheck size={20} strokeWidth={1.5} style={{ color: C.navy }} />
                                    <div>
                                        <h2 className="text-[14px] font-semibold tracking-[0.1em] uppercase" style={{ color: C.text }}>
                                            {selectedRecord.filename}
                                        </h2>
                                        <p className="text-[10px] mt-0.5 font-mono" style={{ color: C.faint }}>
                                            {formatDate(selectedRecord.timestamp)} &middot; SHA-256: {selectedRecord.file_hash?.slice(0, 16)}...
                                        </p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <StatusBadge status={selectedRecord.verification_status} />
                                    <button onClick={() => setSelectedRecord(null)}
                                        className="p-2 rounded-sm hover:bg-gray-100 transition-colors">
                                        <X size={18} strokeWidth={1.5} style={{ color: C.faint }} />
                                    </button>
                                </div>
                            </div>

                            {/* Modal Body */}
                            <div className="px-8 py-6 space-y-6 max-h-[70vh] overflow-y-auto">

                                {/* Executive Summary */}
                                {selectedRecord.executive_summary && (
                                    <div>
                                        <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em] mb-2" style={{ color: C.navy }}>
                                            Executive Summary
                                        </h3>
                                        <p className="text-[12px] leading-relaxed" style={{ color: C.body }}>
                                            {selectedRecord.executive_summary}
                                        </p>
                                    </div>
                                )}

                                {/* Stats Grid */}
                                <div className="grid grid-cols-5 gap-4">
                                    {[
                                        { label: 'Paragraphs', value: selectedRecord.paragraphs_count },
                                        { label: 'Variables', value: selectedRecord.variables_count },
                                        { label: 'COMP-3', value: selectedRecord.comp3_count },
                                        { label: 'Python Size', value: `${(selectedRecord.python_chars || 0).toLocaleString()} chars` },
                                        { label: 'Checklist', value: `${selectedRecord.checklist_pass}/${selectedRecord.checklist_total}`, color: selectedRecord.checklist_pass === selectedRecord.checklist_total ? C.green : C.amber },
                                    ].map(s => (
                                        <div key={s.label} className="px-4 py-3 border rounded-sm" style={{ borderColor: C.border, backgroundColor: C.bgAlt }}>
                                            <p className="text-[10px] uppercase tracking-wider mb-1" style={{ color: C.faint }}>{s.label}</p>
                                            <p className="text-[16px] font-semibold font-mono" style={{ color: s.color || C.text }}>{s.value}</p>
                                        </div>
                                    ))}
                                </div>

                                {/* Arithmetic Risks */}
                                <div>
                                    <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em] mb-2" style={{ color: C.navy }}>
                                        Arithmetic Risks
                                    </h3>
                                    <div className="flex gap-4">
                                        {[
                                            { label: 'Safe', value: selectedRecord.arithmetic_safe, color: C.green, bg: C.greenBg },
                                            { label: 'Warning', value: selectedRecord.arithmetic_warn, color: C.amber, bg: C.amberBg },
                                            { label: 'Critical', value: selectedRecord.arithmetic_critical, color: C.red, bg: C.redBg },
                                        ].map(r => (
                                            <div key={r.label} className="flex items-center gap-2 px-4 py-2 rounded-sm text-[12px] font-mono font-semibold"
                                                style={{ backgroundColor: r.bg, color: r.color }}>
                                                {r.value} {r.label}
                                            </div>
                                        ))}
                                        {selectedRecord.human_review_flags > 0 && (
                                            <div className="flex items-center gap-2 px-4 py-2 rounded-sm text-[12px] font-mono font-semibold"
                                                style={{ backgroundColor: C.amberBg, color: C.amber }}>
                                                {selectedRecord.human_review_flags} Review Flags
                                            </div>
                                        )}
                                    </div>
                                </div>

                                {/* Cryptographic Verification */}
                                <div>
                                    <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em] mb-2" style={{ color: C.navy }}>
                                        Cryptographic Verification
                                    </h3>
                                    {selectedRecord.signature ? (
                                        <div className="space-y-3">
                                            <div className="flex items-center gap-3">
                                                <span className="inline-flex items-center gap-1.5 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.08em] rounded-sm"
                                                    style={{ color: C.green, backgroundColor: C.greenBg, border: `1px solid ${C.greenBorder}` }}>
                                                    <ShieldCheck size={11} strokeWidth={2} />
                                                    Signed
                                                </span>
                                                <span className="text-[10px] font-mono" style={{ color: C.faint }}>
                                                    {selectedRecord.public_key_fp?.slice(0, 24)}...
                                                </span>
                                            </div>
                                            {(() => {
                                                let chain = {};
                                                try { chain = JSON.parse(selectedRecord.verification_chain || '{}'); } catch { /* empty */ }
                                                return chain.chain_hash ? (
                                                    <div className="px-4 py-3 border rounded-sm font-mono text-[10px]"
                                                        style={{ borderColor: C.border, backgroundColor: C.bgAlt, color: C.body }}>
                                                        <span className="text-[9px] uppercase tracking-wider font-semibold" style={{ color: C.faint }}>Chain Hash: </span>
                                                        {chain.chain_hash.slice(0, 32)}...
                                                    </div>
                                                ) : null;
                                            })()}
                                            <div className="flex items-center gap-3">
                                                <button
                                                    onClick={() => handleVerify(selectedRecord.id)}
                                                    disabled={verifying}
                                                    className="flex items-center gap-2 px-4 py-2 text-[10px] font-semibold uppercase tracking-wider rounded-sm border transition-colors"
                                                    style={{ color: C.navy, borderColor: C.border }}
                                                >
                                                    <ShieldCheck size={12} strokeWidth={1.5} />
                                                    {verifying ? 'Verifying...' : 'Verify Signature'}
                                                </button>
                                                {verifyResult && (
                                                    <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold"
                                                        style={{ color: verifyResult.valid ? C.green : C.red }}>
                                                        {verifyResult.valid
                                                            ? <><CheckCircle size={13} strokeWidth={2} /> VALID</>
                                                            : <><AlertTriangle size={13} strokeWidth={2} /> INVALID</>
                                                        }
                                                    </span>
                                                )}
                                            </div>
                                        </div>
                                    ) : (
                                        <div className="flex items-center gap-2 px-4 py-3 rounded-sm border text-[11px]"
                                            style={{ borderColor: C.border, backgroundColor: C.bgAlt, color: C.faint }}>
                                            <Lock size={13} strokeWidth={1.5} />
                                            No cryptographic signature — record predates signing feature
                                        </div>
                                    )}
                                </div>

                                {/* Generated Python */}
                                {selectedRecord.generated_python && (
                                    <div>
                                        <div className="flex items-center justify-between mb-2">
                                            <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em]" style={{ color: C.navy }}>
                                                Verification Model
                                            </h3>
                                            <button
                                                onClick={() => handleCopyPython(selectedRecord.generated_python)}
                                                className="flex items-center gap-1.5 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider rounded-sm border transition-colors"
                                                style={{
                                                    color: copySuccess ? C.green : C.navy,
                                                    borderColor: copySuccess ? C.greenBorder : C.border,
                                                    backgroundColor: copySuccess ? C.greenBg : C.bg,
                                                }}
                                            >
                                                <Copy size={12} strokeWidth={1.5} />
                                                {copySuccess ? 'Copied' : 'Copy'}
                                            </button>
                                        </div>
                                        <pre className="p-4 rounded-sm border overflow-x-auto text-[11px] leading-relaxed font-mono max-h-[400px] overflow-y-auto"
                                            style={{ backgroundColor: C.bgAlt, borderColor: C.border, color: C.text }}>
                                            {selectedRecord.generated_python}
                                        </pre>
                                    </div>
                                )}
                            </div>

                            {/* Modal Footer */}
                            <div className="flex justify-end gap-3 px-8 py-4 border-t" style={{ borderColor: C.border }}>
                                <button
                                    onClick={() => handleReexportPDF(selectedRecord)}
                                    className="flex items-center gap-2 px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] rounded-sm border transition-colors"
                                    style={{ color: C.navy, borderColor: C.border }}
                                >
                                    <Download size={14} strokeWidth={1.5} />
                                    Re-export PDF
                                </button>
                                <button
                                    onClick={() => setSelectedRecord(null)}
                                    className="px-5 py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] rounded-sm"
                                    style={{ backgroundColor: C.navy, color: '#FFFFFF' }}
                                >
                                    Close
                                </button>
                            </div>
                    </div>
                </div>
            )}

            {/* Detail loading overlay */}
            {detailLoading && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/20">
                    <div className="bg-white p-6 rounded-sm border shadow-lg" style={{ borderColor: C.border }}>
                        <div className="inline-block w-6 h-6 border-2 rounded-full animate-spin"
                            style={{ borderColor: C.border, borderTopColor: C.navy }} />
                    </div>
                </div>
            )}
        </div>
    );
};

export default Vault;
