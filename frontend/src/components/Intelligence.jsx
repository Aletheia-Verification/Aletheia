import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    AlertTriangle,
    ShieldAlert,
    Zap,
    Search,
    ChevronRight,
    PieChart,
    BarChart,
    FileQuestion
} from 'lucide-react';
import { apiUrl } from '../config/api';

const RiskItem = ({ type, title, count, severity }) => {
    const sevColor = severity === 'Critical' ? 'text-red-500' : severity === 'High' ? 'text-amber-500' : 'text-primary';
    const sevBg = severity === 'Critical' ? 'bg-red-500/10' : severity === 'High' ? 'bg-amber-500/10' : 'bg-primary/10';

    return (
        <div className="flex items-center justify-between p-4 bg-surface/20 border border-border rounded-xl group hover:border-primary/30 transition-all">
            <div className="flex items-center gap-4">
                <div className={`p-2 rounded-lg ${sevBg} ${sevColor}`}>
                    <AlertTriangle size={18} />
                </div>
                <div className="space-y-0.5">
                    <h4 className="text-xs font-mono font-bold tracking-tight text-text uppercase">{title}</h4>
                    <span className="text-[10px] text-text-dim uppercase tracking-widest">{type}</span>
                </div>
            </div>
            <div className="text-right">
                <div className={`text-sm font-mono font-bold ${sevColor}`}>{count}</div>
                <div className="text-[9px] text-text-dim uppercase tracking-tighter">Occurrences</div>
            </div>
        </div>
    );
};

const EmptyState = ({ icon: Icon, title, description }) => (
    <div className="flex flex-col items-center justify-center py-12 text-center">
        <div className="p-4 bg-surface/30 rounded-full mb-4">
            <Icon size={24} className="text-text-dim/40" strokeWidth={1.5} />
        </div>
        <h4 className="text-[11px] font-mono uppercase tracking-widest text-text-dim mb-2">{title}</h4>
        <p className="text-[10px] text-text-dim/60 max-w-xs">{description}</p>
    </div>
);

const Intelligence = () => {
    const [riskData, setRiskData] = useState(null);
    const [anomalies, setAnomalies] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchRiskIntelligence = async () => {
            try {
                const token = localStorage.getItem('alethia_token');
                const response = await fetch(apiUrl('/risk-intelligence'), {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                if (response.ok) {
                    const data = await response.json();
                    setRiskData(data.distribution);
                    setAnomalies(data.anomalies || []);
                }
            } catch (err) {
                console.error("Risk intelligence fetch failed", err);
            } finally {
                setLoading(false);
            }
        };
        fetchRiskIntelligence();
    }, []);

    const hasRiskData = riskData && riskData.length > 0;
    const hasAnomalies = anomalies && anomalies.length > 0;

    if (loading) {
        return (
            <div className="p-8 flex items-center justify-center min-h-[50vh]">
                <div className="text-[10px] font-mono uppercase tracking-[0.3em] text-text-dim animate-pulse">
                    Synchronizing Risk Intelligence...
                </div>
            </div>
        );
    }

    return (
        <div className="p-8 max-w-[1600px] mx-auto space-y-10">
            {/* Header */}
            <div className="flex justify-between items-end">
                <div className="space-y-1">
                    <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">Risk Intelligence</h1>
                    <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">High-Level Forensic Anomaly Detection</p>
                </div>
                <div className="flex gap-4">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-text-dim" size={14} />
                        <input
                            type="text"
                            placeholder="SEARCH AUDIT TRAIL..."
                            className="bg-surface/40 border border-border rounded-lg py-2 pl-10 pr-4 text-[10px] font-mono tracking-widest focus:outline-none focus:border-primary transition-all"
                        />
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Risk Distribution */}
                <div className="lg:col-span-1 bg-surface/20 border border-border rounded-2xl p-8 space-y-8 flex flex-col justify-center min-h-[400px]">
                    <div className="text-center space-y-2">
                        <PieChart className="mx-auto text-primary opacity-20" size={64} strokeWidth={1} />
                        <h3 className="text-xs font-mono tracking-widest uppercase text-text-dim">Risk Distribution</h3>
                    </div>

                    {hasRiskData ? (
                        <div className="space-y-4">
                            {riskData.map((item, i) => (
                                <div key={i} className="space-y-2">
                                    <div className="flex justify-between text-[10px] uppercase tracking-widest text-text-dim">
                                        <span>{item.label}</span>
                                        <span>{item.value}%</span>
                                    </div>
                                    <div className="h-1 bg-border rounded-full overflow-hidden">
                                        <motion.div
                                            initial={{ width: 0 }}
                                            animate={{ width: `${item.value}%` }}
                                            className="h-full bg-primary"
                                        />
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <EmptyState
                            icon={PieChart}
                            title="No Risk Data"
                            description="Risk distribution will populate after analyses are completed"
                        />
                    )}
                </div>

                {/* Findings Feed */}
                <div className="lg:col-span-2 space-y-4">
                    <div className="bg-surface/20 border border-border rounded-2xl p-8 space-y-6">
                        <div className="flex items-center gap-3 border-b border-border/50 pb-4">
                            <ShieldAlert className="text-primary" size={18} />
                            <h3 className="text-xs font-mono font-bold tracking-widest uppercase text-text">Detected Anomalies</h3>
                        </div>

                        {hasAnomalies ? (
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {anomalies.map((anomaly, idx) => (
                                    <RiskItem
                                        key={idx}
                                        type={anomaly.type}
                                        title={anomaly.title}
                                        count={anomaly.count}
                                        severity={anomaly.severity}
                                    />
                                ))}
                            </div>
                        ) : (
                            <EmptyState
                                icon={FileQuestion}
                                title="No Anomalies Detected"
                                description="Anomalies will appear here as COBOL assets are analyzed through the Engine"
                            />
                        )}

                        <div className="pt-6">
                            <div className="bg-primary/5 border border-primary/20 rounded-xl p-6 flex items-center justify-between group cursor-pointer hover:bg-primary/10 transition-all">
                                <div className="flex gap-4 items-center">
                                    <Zap className="text-primary" size={24} />
                                    <div className="space-y-1">
                                        <h4 className="text-xs font-mono font-bold tracking-widest uppercase">Launch Global Logic Sweep</h4>
                                        <p className="text-[10px] text-text-dim uppercase">Initiate deep forensic analysis across all vaulted assets</p>
                                    </div>
                                </div>
                                <ChevronRight className="text-primary group-hover:translate-x-2 transition-transform" />
                            </div>
                        </div>
                    </div>

                    <div className="bg-surface/20 border border-border rounded-2xl p-8 flex items-center justify-between">
                        <div className="flex items-center gap-6">
                            <BarChart className="text-text-dim" size={32} strokeWidth={1} />
                            <div className="space-y-1">
                                <span className="text-[10px] text-primary uppercase font-mono tracking-widest">Archive Integrity</span>
                                <h4 className="text-lg font-mono text-text-dim/60 italic">Awaiting data</h4>
                            </div>
                        </div>
                        <button className="text-[10px] uppercase font-mono tracking-widest text-text-dim/40 cursor-not-allowed">
                            View Detailed Ledger
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Intelligence;
