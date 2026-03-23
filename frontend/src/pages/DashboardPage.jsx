import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { LayoutDashboard, Cpu, FileText, Activity } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useAuth } from '../context/AuthContext';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import StatusBadge from '../components/StatusBadge';
import LoadingState from '../components/LoadingState';

const POLL_INTERVAL = 60000;

const TrendIndicator = ({ current, previous, C }) => {
    if (!C) C = LIGHT;
    if (previous === null || previous === undefined || current === previous) return null;
    const up = current > previous;
    return (
        <span style={{ color: up ? C.green : '#DC2626', marginLeft: 4, fontSize: '0.75rem', fontFamily: 'monospace' }}>
            {up ? '↑' : '↓'}{Math.abs(current - previous)}
        </span>
    );
};

const StatCard = ({ label, value, trend, accent, icon: Icon, C: _C }) => {
    const C = _C || LIGHT;
    return (
    <div className="rounded-xl shadow-sm p-6" style={{ backgroundColor: C.bg, border: `1px solid ${C.border}` }}>
        <div className="flex items-center gap-2 mb-3">
            {Icon && <Icon size={14} strokeWidth={1.5} style={{ color: C.faint }} />}
            <span className="text-[12px]" style={{ color: C.faint }}>
                {label}
            </span>
        </div>
        <div className="text-2xl font-bold flex items-baseline" style={{ color: accent || C.navy }}>
            {value}
            {trend}
        </div>
    </div>
    );
};

const DashboardPage = () => {
    const C = useColors() || LIGHT;
    const navigate = useNavigate();
    const auth = useAuth();
    const [records, setRecords] = useState([]);
    const [analytics, setAnalytics] = useState(null);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [lastUpdated, setLastUpdated] = useState(null);
    const [secondsAgo, setSecondsAgo] = useState(0);
    const [healthStatus, setHealthStatus] = useState('checking');

    // Store previous values for trend comparison
    const prevRef = useRef({ records: 0, verified: 0, manual: 0 });

    const fetchData = useCallback(async (isInitial = false) => {
        if (isInitial) setLoading(true);
        else setRefreshing(true);
        try {
            // Health check (no auth required)
            try {
                const healthRes = await authApi.get('/api/health');
                setHealthStatus(healthRes.ok ? 'online' : 'degraded');
            } catch {
                setHealthStatus('degraded');
            }

            const [vaultRes, analyticsRes] = await Promise.all([
                authApi.get('/vault/list'),
                authApi.get('/analytics'),
            ]);
            let newRecords = [];
            if (vaultRes.ok) {
                const data = await vaultRes.json();
                newRecords = Array.isArray(data) ? data : data.records || [];
            }
            let newAnalytics = null;
            if (analyticsRes.ok) {
                newAnalytics = await analyticsRes.json();
            }
            // Save current as previous before updating (skip on first load)
            if (!isInitial) {
                prevRef.current = {
                    records: records.length,
                    verified: records.filter(r => r.verdict === 'VERIFIED').length,
                    manual: records.filter(r => r.verdict !== 'VERIFIED').length,
                };
            }
            setRecords(newRecords);
            setAnalytics(newAnalytics);
            setLastUpdated(new Date());
        } catch (e) {
            if (import.meta.env.DEV) console.error('Dashboard fetch:', e);
        } finally {
            if (isInitial) setLoading(false);
            else setRefreshing(false);
        }
    }, [records]);

    // Initial load
    useEffect(() => { fetchData(true); }, []); // eslint-disable-line react-hooks/exhaustive-deps

    // 30s polling
    useEffect(() => {
        const id = setInterval(() => fetchData(false), POLL_INTERVAL);
        return () => clearInterval(id);
    }, [fetchData]);

    // Seconds-ago ticker
    useEffect(() => {
        const id = setInterval(() => {
            if (lastUpdated) {
                setSecondsAgo(Math.floor((Date.now() - lastUpdated.getTime()) / 1000));
            }
        }, 1000);
        return () => clearInterval(id);
    }, [lastUpdated]);

    if (loading) return <LoadingState label="Loading dashboard..." />;

    const verified = records.filter(r => r.verdict === 'VERIFIED').length;
    const manual = records.filter(r => r.verdict !== 'VERIFIED').length;
    const prev = prevRef.current;

    if (records.length === 0) {
        return (
            <div>
                <PageHeader
                    icon={LayoutDashboard}
                    title="Dashboard"
                    subtitle={`Welcome back, ${auth.userProfile?.username || auth.corporateId || 'Operator'}`}
                />
                <div className="text-center py-20 space-y-3">
                    <p className="text-sm" style={{ color: C.muted }}>No verifications yet</p>
                    <a
                        href="/analyze"
                        className="inline-block text-xs tracking-[0.12em] uppercase font-medium hover:opacity-80 transition-opacity"
                        style={{ color: C.navy }}
                    >
                        Run your first analysis
                    </a>
                </div>
            </div>
        );
    }

    return (
        <div>
            <PageHeader
                icon={LayoutDashboard}
                title="Dashboard"
                subtitle={`Welcome back, ${auth.userProfile?.username || auth.corporateId || 'Operator'}`}
            />

            {/* Live Status Bar */}
            <div className="flex items-center justify-between mb-4">
                <span className="text-[10px] tracking-[0.08em] uppercase" style={{ color: C.faint }}>
                    {lastUpdated ? `Updated ${secondsAgo}s ago` : ''}
                    {refreshing && (
                        <span style={{ marginLeft: 8, color: C.gold, fontSize: '0.7rem' }}>●</span>
                    )}
                </span>
                <button
                    onClick={() => fetchData(false)}
                    disabled={refreshing}
                    className="text-[10px] tracking-[0.12em] uppercase font-semibold transition-all duration-150"
                    style={{
                        background: 'transparent',
                        border: `1px solid ${C.border}`,
                        padding: '4px 14px',
                        cursor: refreshing ? 'not-allowed' : 'pointer',
                        color: refreshing ? C.faint : C.text,
                        opacity: refreshing ? 0.6 : 1,
                    }}
                >
                    {refreshing ? 'Refreshing...' : 'Refresh'}
                </button>
            </div>

            {/* Hero: VERIFIED count */}
            <div className="text-center mb-8">
                <div className="text-6xl font-bold" style={{ color: verified > 0 ? C.green : C.faint }}>
                    {verified}
                </div>
                <div className="text-sm mt-1" style={{ color: C.muted }}>
                    Programs Verified
                </div>
            </div>

            {/* Stat Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                <StatCard
                    label="Total Verifications"
                    value={records.length}
                    trend={<TrendIndicator current={records.length} previous={prev.records || null} C={C} />}
                    icon={FileText}
                    accent={C.navy}
                    C={C}
                />
                <StatCard
                    label="Verified"
                    value={verified}
                    trend={<TrendIndicator current={verified} previous={prev.verified || null} C={C} />}
                    icon={Activity}
                    accent={C.green}
                    C={C}
                />
                <StatCard
                    label="Manual Review"
                    value={manual}
                    trend={<TrendIndicator current={manual} previous={prev.manual || null} C={C} />}
                    icon={Activity}
                    accent="#DC2626"
                    C={C}
                />
                <StatCard
                    label="System Status"
                    value={
                        <span className="flex items-center gap-2">
                            <span className={`w-2 h-2 rounded-full inline-block ${
                                healthStatus === 'online' ? 'bg-green-500' :
                                healthStatus === 'degraded' ? 'bg-red-500' : 'bg-gray-400'
                            }`} />
                            <span className="text-sm">
                                {healthStatus === 'online' ? 'Online' :
                                 healthStatus === 'degraded' ? 'Degraded' : 'Checking...'}
                            </span>
                        </span>
                    }
                    icon={Activity}
                    accent={healthStatus === 'online' ? C.green : healthStatus === 'degraded' ? '#DC2626' : C.gold}
                    C={C}
                />
            </div>

            {/* Trend Chart (last 14 days) */}
            {records.length > 0 && (() => {
                const days = {};
                const today = new Date();
                for (let d = 13; d >= 0; d--) {
                    const dt = new Date(today);
                    dt.setDate(dt.getDate() - d);
                    const key = dt.toISOString().slice(0, 10);
                    days[key] = { date: key, verified: 0, manual: 0 };
                }
                records.forEach(r => {
                    if (!r.timestamp) return;
                    const key = new Date(r.timestamp).toISOString().slice(0, 10);
                    if (days[key]) {
                        const status = r.verdict || r.verification_status;
                        if (status === 'VERIFIED') days[key].verified++;
                        else days[key].manual++;
                    }
                });
                const data = Object.values(days);
                const maxVal = Math.max(1, ...data.map(d => d.verified + d.manual));
                const barW = 100 / data.length;
                const chartH = 120;

                return (
                    <div className="mb-8">
                        <h2 className="text-[11px] tracking-[0.2em] uppercase font-semibold mb-4" style={{ color: C.text }}>
                            Verification Trend
                        </h2>
                        <div className="border p-4" style={{ borderColor: C.border }}>
                            <svg width="100%" height={chartH} viewBox={`0 0 ${data.length * 40} ${chartH}`} preserveAspectRatio="none">
                                {data.map((d, i) => {
                                    const total = d.verified + d.manual;
                                    const totalH = (total / maxVal) * (chartH - 20);
                                    const verH = (d.verified / maxVal) * (chartH - 20);
                                    const manH = totalH - verH;
                                    const x = i * 40 + 4;
                                    const w = 32;
                                    return (
                                        <g key={i}>
                                            {verH > 0 && (
                                                <rect x={x} y={chartH - 20 - totalH + manH} width={w} height={verH} fill={C.navy} />
                                            )}
                                            {manH > 0 && (
                                                <rect x={x} y={chartH - 20 - totalH} width={w} height={manH} fill="#D97706" />
                                            )}
                                            <text x={x + w / 2} y={chartH - 4} textAnchor="middle" fontSize="11" fill={C.body} fontFamily="monospace">
                                                {d.date.slice(5)}
                                            </text>
                                        </g>
                                    );
                                })}
                            </svg>
                            <div className="flex gap-4 mt-2">
                                <span className="flex items-center gap-1 text-[9px] uppercase tracking-wider" style={{ color: C.faint }}>
                                    <span className="w-2 h-2 inline-block" style={{ backgroundColor: C.navy }} /> Verified
                                </span>
                                <span className="flex items-center gap-1 text-[9px] uppercase tracking-wider" style={{ color: C.faint }}>
                                    <span className="w-2 h-2 inline-block" style={{ backgroundColor: '#D97706' }} /> Manual Review
                                </span>
                            </div>
                        </div>
                    </div>
                );
            })()}

            {/* Recent Verifications */}
            <div className="mb-8">
                <h2 className="text-[11px] tracking-[0.2em] uppercase font-semibold mb-4" style={{ color: C.text }}>
                    Recent Verifications
                </h2>
                {records.length === 0 ? (
                    <div className="text-center py-12">
                        <p className="text-sm mb-3" style={{ color: C.faint }}>No verifications yet.</p>
                        <button
                            onClick={() => navigate('/analyze')}
                            className="text-sm px-5 py-2 rounded-lg transition-opacity hover:opacity-90"
                            style={{ backgroundColor: C.navy, color: 'white' }}
                        >
                            Run your first analysis
                        </button>
                    </div>
                ) : (
                    <div className="border" style={{ borderColor: C.border }}>
                        <table className="w-full text-left">
                            <thead>
                                <tr style={{ backgroundColor: C.bgAlt }}>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>File</th>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Date</th>
                                    <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Verdict</th>
                                </tr>
                            </thead>
                            <tbody>
                                {records.slice(0, 5).map((r, i) => (
                                    <tr key={r.id || i} className="border-t" style={{ borderColor: C.border }}>
                                        <td className="px-4 py-3 text-[11px] font-mono" style={{ color: C.text }}>
                                            {r.filename || 'Unknown'}
                                        </td>
                                        <td className="px-4 py-3 text-[13px]" style={{ color: C.body }}>
                                            {r.timestamp ? new Date(r.timestamp).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'}
                                        </td>
                                        <td className="px-4 py-3">
                                            <StatusBadge status={r.verdict === 'VERIFIED' ? 'green' : 'red'} label={r.verdict} />
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Quick Actions */}
            <div className="flex gap-3">
                <button
                    onClick={() => navigate('/analyze')}
                    className="px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90"
                    style={{ backgroundColor: C.navy }}
                >
                    New Analysis
                </button>
                <button
                    onClick={() => navigate('/portfolio')}
                    className="px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                    style={{ borderColor: C.navy, color: C.navy }}
                >
                    Portfolio Heatmap
                </button>
                <button
                    onClick={() => navigate('/reports')}
                    className="px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                    style={{ borderColor: C.border, color: C.faint }}
                >
                    View Reports
                </button>
            </div>
        </div>
    );
};

export default DashboardPage;
