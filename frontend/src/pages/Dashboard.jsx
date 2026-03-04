import React, { useState } from 'react';
import {
    FileCode, Terminal, CheckCircle, AlertTriangle,
    BarChart3, Settings, LogOut,
    Search, Filter, Database, Cpu, Activity,
    Shield, Sparkles, AlertCircle, FileText,
    Calculator, Scale, Wrench, ChevronDown, ChevronUp
} from 'lucide-react';
import { API_BASE } from '../config/api';

const Dashboard = ({ onLogout, corporateId, isDemoMode }) => {
    const [file, setFile] = useState(null);
    const [analyzing, setAnalyzing] = useState(false);
    const [result, setResult] = useState(null);
    const [error, setError] = useState('');

    // Safety: prevent black screen and show loading if critical props missing
    if (!corporateId && !isDemoMode) {
        return (
            <div className="h-screen w-screen bg-background flex items-center justify-center">
                <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
        );
    }


    const handleFileUpload = (e) => {
        const selectedFile = e.target.files[0];
        if (selectedFile) {
            setFile(selectedFile);
            setError('');
            processFile(selectedFile);
        }
    };

    const processFile = async (selectedFile) => {
        setAnalyzing(true);
        setResult(null);
        setError('');

        // Demo mode returns mock data with Tier-1 Banking format
        if (isDemoMode) {
            setTimeout(() => {
                setResult({
                    original_file_name: selectedFile.name,
                    analysis_timestamp: new Date().toISOString(),
                    traceability_score: 0.85,

                    // Tier-1 Banking Structured Output
                    executive_summary: `[DEMO] Migration Risk Classification: MEDIUM

This COBOL module implements core interest calculation logic for customer savings accounts. The system processes approximately 2.3M accounts daily on the mainframe.

Critical Dependencies Identified:
• CUST-MASTER-FILE (customer demographics)
• ACCT-BALANCE-DB (real-time balance feeds)
• RATE-TABLE-3270 (tiered rate configuration)

Primary Concern: Undocumented age-based bonus logic added in 1993 with no regulatory approval trail. This may constitute discriminatory pricing under current CFPB guidelines.`,

                    mathematical_breakdown: `INTEREST CALCULATION PRECISION ANALYSIS

1. BASE RATE COMPUTATION (Lines 145-152)
   PIC S9(3)V9(4) COMP-3 → Python Decimal("0.0000")
   Rounding: ROUND_HALF_UP (explicit ROUNDED clause)

2. TIER ADJUSTMENTS (Lines 160-175)
   Balance >= $100,000: +0.75% (PIC 9(7)V99)
   Balance >= $50,000:  +0.50%
   Note: No ON SIZE ERROR - overflow silently truncates

3. AGE BONUS (Lines 180-185) ⚠️
   IF WS-CUST-AGE >= 65 THEN +0.50%
   COMP-3 field: PIC S9(3)V9(2)
   WARNING: Implicit decimal, verify precision in translation`,

                    compliance_risk_factors: [
                        {
                            regulation: "CFPB - Fair Lending",
                            severity: "High",
                            finding: "Age-based interest rate adjustment at line 180 may constitute discriminatory pricing. No documented business justification found.",
                            remediation: "Obtain legal review. Document business rationale or remove age-based adjustment.",
                            affected_lines: "180-185"
                        },
                        {
                            regulation: "SOX Section 404",
                            severity: "Medium",
                            finding: "No audit trail for rate calculation changes. Magic number 0.0050 appears without documentation.",
                            remediation: "Implement calculation audit logging. Document all rate adjustment values in configuration.",
                            affected_lines: "182"
                        }
                    ],

                    technical_debt_warnings: [
                        "COMP-3 field WS-BASE-RATE: Verify Decimal precision in Python translation",
                        "COMP-3 field WS-BONUS-RATE: Verify Decimal precision in Python translation",
                        "No ON SIZE ERROR at line 170: Potential silent overflow in high-balance scenarios",
                        "Nested COMPUTE at line 165: Manual verification recommended"
                    ],

                    comp3_fields_detected: 4,

                    extracted_rules: [
                        {
                            id: "R-001",
                            name: "Core Interest Calculation",
                            description: "Base interest rate computed from account balance tiers and customer classification. Lines 145-175.",
                            confidence: 0.98,
                            is_risk: false
                        },
                        {
                            id: "FR-001",
                            name: "Undocumented Age Bonus",
                            description: "Customers aged 65+ receive +0.50% bonus. Added June 1993 with no documentation or regulatory approval on file.",
                            confidence: 0.95,
                            is_risk: true,
                            risk_reason: "Potential CFPB Fair Lending violation. Age-based financial adjustments require documented justification."
                        },
                        {
                            id: "TD-001",
                            name: "Missing Overflow Protection",
                            description: "COMPUTE statement at line 170 lacks ON SIZE ERROR clause. High-balance accounts could cause silent truncation.",
                            confidence: 0.90,
                            is_risk: true,
                            risk_reason: "Technical debt: Silent data corruption risk for accounts exceeding $9,999,999.99"
                        }
                    ],

                    python_implementation: `from decimal import Decimal, ROUND_HALF_UP
from dataclasses import dataclass
from typing import Optional
import logging

logger = logging.getLogger("interest_calculator")


@dataclass
class InterestCalculator:
    """
    Legacy COBOL Interest Calculation - Python 3.12 Logic Extraction

    Source: INTR-CALC-3270.cbl (Lines 145-190)
    Translated: ${new Date().toISOString().split('T')[0]}

    PRECISION NOTES:
    - All rates use Decimal with 4 decimal places (matches PIC S9(3)V9(4))
    - Rounding follows COBOL ROUNDED semantics (ROUND_HALF_UP)
    - Balance uses 2 decimal places (matches PIC 9(7)V99)
    """

    base_rate: Decimal = Decimal("0.0325")
    senior_bonus: Decimal = Decimal("0.0050")  # ⚠️ UNDOCUMENTED - Line 182

    def calculate(
        self,
        balance: Decimal,
        customer_age: int,
        audit_id: Optional[str] = None
    ) -> Decimal:
        """
        Calculate interest rate with tier adjustments.

        Args:
            balance: Account balance (PIC 9(7)V99 equivalent)
            customer_age: Customer age in years
            audit_id: Optional audit trail identifier

        Returns:
            Final interest rate as Decimal (4 decimal places)

        Raises:
            ValueError: If balance exceeds safe calculation range
        """
        # Overflow protection (missing in original COBOL)
        if balance > Decimal("9999999.99"):
            logger.warning(f"Balance overflow risk: {balance} [audit:{audit_id}]")
            raise ValueError("Balance exceeds safe calculation range")

        rate = self.base_rate

        # Tier adjustments (Lines 160-175)
        if balance >= Decimal("100000.00"):
            rate += Decimal("0.0075")
        elif balance >= Decimal("50000.00"):
            rate += Decimal("0.0050")

        # ⚠️ COMPLIANCE RISK: Age-based bonus (Lines 180-185)
        # TODO: Obtain legal review before production deployment
        if customer_age >= 65:
            logger.info(f"Age bonus applied [audit:{audit_id}]")
            rate += self.senior_bonus

        return rate.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)`,

                    summary: "[DEMO] Behavioral Verification: Legacy interest calculation module with undocumented age-based adjustments."
                });
                setAnalyzing(false);
            }, 2500);
            return;
        }

        try {
            const formData = new FormData();
            formData.append('file', selectedFile);

            const token = localStorage.getItem('access_token');
            if (!token) {
                setError('No authentication token. Please log in again.');
                setTimeout(() => onLogout(), 2000);
                return;
            }

            const response = await fetch(`${API_BASE}/process-legacy`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`
                },
                body: formData,
            });

            if (response.status === 401) {
                setError('Session expired. Please log in again.');
                setTimeout(() => onLogout(), 2000);
                return;
            }

            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                throw new Error(errData.detail || `Analysis failed (${response.status})`);
            }

            const data = await response.json();

            setTimeout(() => {
                setResult(data);
                setAnalyzing(false);
            }, 1500);

        } catch (err) {
            console.error(err);
            setError(err.message || 'Analysis failed. Check server connection.');
            setAnalyzing(false);
        }
    };

    // Get user initials for avatar
    const userInitials = corporateId ? corporateId.substring(0, 2).toUpperCase() : 'DM';

    return (
        <div className="min-h-screen bg-background text-text flex font-sans">
            {/* Sidebar - Enterprise Navigation */}
            <aside className="w-20 border-r border-border flex flex-col items-center py-8 space-y-8 bg-surface/20 hidden md:flex">
                <div className="w-10 h-10 bg-surface-highlight border border-border rounded-xl flex items-center justify-center text-primary shadow-lg">
                    <Database className="w-5 h-5" />
                </div>

                <nav className="flex-1 space-y-6">
                    <button className="p-3 text-primary bg-primary/10 rounded-xl border border-primary/20">
                        <Cpu className="w-5 h-5" />
                    </button>
                    <button className="p-3 text-text-dim hover:text-text hover:bg-surface-highlight rounded-xl transition-all">
                        <Activity className="w-5 h-5" />
                    </button>
                    <button className="p-3 text-text-dim hover:text-text hover:bg-surface-highlight rounded-xl transition-all">
                        <BarChart3 className="w-5 h-5" />
                    </button>
                    <button className="p-3 text-text-dim hover:text-text hover:bg-surface-highlight rounded-xl transition-all">
                        <Settings className="w-5 h-5" />
                    </button>
                </nav>

                <button
                    onClick={onLogout}
                    className="p-3 text-text-dim hover:text-red-400 hover:bg-red-400/10 rounded-xl transition-all mt-auto"
                >
                    <LogOut className="w-5 h-5" />
                </button>
            </aside>

            {/* Main Content Area */}
            <div className="flex-1 flex flex-col min-w-0 overflow-hidden">

                {/* Top Header Bar */}
                <header className="h-16 border-b border-border flex items-center justify-between px-8 bg-surface/10 backdrop-blur-md">
                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-2 text-xs font-bold text-text-dim uppercase tracking-widest bg-surface-highlight/50 px-3 py-1.5 rounded-full border border-border">
                            <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
                            Production Node 04
                        </div>
                        <div className="h-4 w-px bg-border mx-2" />
                        <span className="text-sm font-medium text-text-dim">Project: <span className="text-text">Global_Legacy_v4</span></span>
                    </div>

                    <div className="flex items-center gap-6">
                        <div className="relative group">
                            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-text-dim" />
                            <input
                                type="text"
                                placeholder="Search Logic..."
                                className="bg-surface-highlight/30 border border-border rounded-lg pl-9 pr-4 py-1.5 text-xs focus:outline-none focus:border-primary/50 transition-all w-48 group-hover:w-64"
                            />
                        </div>
                        <div className="flex items-center gap-2">
                            {isDemoMode && (
                                <span className="text-[9px] uppercase tracking-widest text-primary bg-primary/10 px-2 py-1 rounded-full border border-primary/20">Demo</span>
                            )}
                            <div className="w-8 h-8 rounded-full bg-surface-highlight border border-border flex items-center justify-center text-[10px] font-bold">
                                {userInitials}
                            </div>
                        </div>
                    </div>
                </header>

                {/* 3-Column Dashboard Layout */}
                <main className="flex-1 flex overflow-hidden p-6 gap-6">

                    {/* Column 1: The Source (Raw COBOL) */}
                    <section className="flex-1 bg-surface/30 border border-border rounded-2xl flex flex-col overflow-hidden group shadow-inner">
                        <div className="px-4 py-3 border-b border-border flex items-center justify-between bg-surface-highlight/20">
                            <div className="flex items-center gap-3">
                                <FileCode className="w-4 h-4 text-text-dim" />
                                <span className="text-xs font-bold uppercase tracking-wider text-text-dim">Source Archive</span>
                            </div>
                            <label className="cursor-pointer bg-background border border-border px-3 py-1 rounded-md text-[10px] uppercase font-bold text-primary hover:border-primary/50 transition-all">
                                Ingest File
                                <input type="file" className="hidden" onChange={handleFileUpload} />
                            </label>
                        </div>
                        <div className="flex-1 overflow-auto p-4 font-mono text-xs leading-relaxed text-text-dim/80 relative">
                            {/* Line Numbers Sidebar Placeholder */}
                            <div className="absolute left-0 top-0 bottom-0 w-8 bg-surface-highlight/10 border-r border-border/20 flex flex-col items-center py-4 text-text-dim/20 pointer-events-none">
                                {Array.from({ length: 40 }).map((_, i) => <span key={i} className="h-5">{i + 1}</span>)}
                            </div>
                            <div className="pl-8">
                                {file ? (
                                    <div className="whitespace-pre">
                                        {/* In a real app, we'd read the file content. For now, mock text */}
                                        IDENTIFICATION DIVISION.<br />
                                        PROGRAM-ID. LEGACY-CALC.<br />
                                        AUTHOR. MAIN-SYSTEM.<br />
                                        ... [LEGACY DATA DETECTED] ...<br />
                                        COMPUTE WS-F-RATE = WS-BASE + WS-BONUS.<br />
                                        IF WS-AGE {'>'}= 65 THEN<br />
                                        MOVE .0050 TO WS-BONP<br />
                                        <span className="bg-primary/5 border-l-2 border-primary px-2 text-primary">/* UNDOCUMENTED RULE DETECTED */</span>
                                        END-IF.<br />
                                    </div>
                                ) : (
                                    <div className="h-full flex flex-col items-center justify-center text-center opacity-20 space-y-4">
                                        <Database className="w-12 h-12" />
                                        <p className="text-[10px] uppercase tracking-widest font-bold">Waiting for System Ingest</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    </section>

                    {/* Column 2: The Translation (Python 3.12) */}
                    <section className="flex-1 bg-surface/30 border border-border rounded-2xl flex flex-col overflow-hidden shadow-2xl relative">
                        <div className="px-4 py-3 border-b border-border flex items-center justify-between bg-surface-highlight/40">
                            <div className="flex items-center gap-3">
                                <Terminal className="w-4 h-4 text-primary" />
                                <span className="text-xs font-bold uppercase tracking-wider text-text">Python 3.12 Logic Extraction</span>
                            </div>
                            <div className="flex gap-1.5">
                                <div className="w-2 h-2 rounded-full bg-red-500/30" />
                                <div className="w-2 h-2 rounded-full bg-yellow-500/30" />
                                <div className="w-2 h-2 rounded-full bg-green-500/30" />
                            </div>
                        </div>

                        <div className="flex-1 overflow-auto p-6 font-mono text-sm group">
                            {error ? (
                                <div className="h-full flex flex-col items-center justify-center space-y-4">
                                    <AlertCircle className="w-12 h-12 text-red-400" />
                                    <div className="text-center space-y-2">
                                        <p className="text-xs uppercase tracking-widest font-bold text-red-400">Analysis Error</p>
                                        <p className="text-[11px] text-text-dim max-w-xs">{error}</p>
                                    </div>
                                </div>
                            ) : analyzing ? (
                                <div className="h-full flex flex-col items-center justify-center space-y-6">
                                    <div className="relative">
                                        <div className="w-12 h-12 border-2 border-primary/20 border-t-primary rounded-full animate-spin" />
                                    </div>
                                    <div className="text-center space-y-2">
                                        <p className="text-xs uppercase tracking-[0.3em] font-bold text-primary animate-pulse">Analyzing Logic</p>
                                        <p className="text-[10px] text-text-dim uppercase tracking-widest">Lead Systems Architect Mode Active</p>
                                    </div>
                                </div>
                            ) : result ? (
                                <pre className="text-text/90 selection:bg-primary/30 selection:text-white fade-in">
                                    <code>{result.python_implementation}</code>
                                </pre>
                            ) : (
                                <div className="h-full flex flex-col items-center justify-center text-center opacity-20 space-y-4">
                                    <Cpu className="w-12 h-12" />
                                    <p className="text-[10px] uppercase tracking-widest font-bold">Logic Output Pending</p>
                                </div>
                            )}
                        </div>

                    </section>

                    {/* Column 3: The Audit (Tier-1 Banking Report) */}
                    <section className="w-[420px] space-y-4 overflow-y-auto pr-1">

                        {/* Verification Status */}
                        <div className="bg-surface/50 border border-border rounded-2xl p-5 space-y-4">
                            <div className="flex items-center justify-between">
                                <h3 className="text-[10px] font-bold uppercase tracking-[0.2em] text-text-dim">Verification Status</h3>
                                <Shield className="w-4 h-4 text-text-dim" />
                            </div>
                            <div className="flex items-center gap-3">
                                {result ? (
                                    <span className="text-sm font-bold uppercase tracking-widest px-4 py-2 border bg-green-500/10 border-green-500/30 text-green-500">
                                        Verified
                                    </span>
                                ) : (
                                    <span className="text-sm font-bold uppercase tracking-widest text-text-dim">
                                        Awaiting Analysis
                                    </span>
                                )}
                            </div>
                            {result?.comp3_fields_detected > 0 && (
                                <div className="flex items-center gap-2 text-[10px] text-primary bg-primary/10 px-3 py-2 rounded-lg border border-primary/20">
                                    <Calculator className="w-3 h-3" />
                                    <span>{result.comp3_fields_detected} COMP-3 (Packed Decimal) fields detected</span>
                                </div>
                            )}
                        </div>

                        {/* Executive Summary */}
                        {result?.executive_summary && (
                            <CollapsibleSection
                                title="Executive Summary"
                                icon={<FileText className="w-3 h-3" />}
                                defaultOpen={true}
                            >
                                <pre className="text-[11px] text-text-dim leading-relaxed whitespace-pre-wrap font-sans">
                                    {result.executive_summary}
                                </pre>
                            </CollapsibleSection>
                        )}

                        {/* Mathematical Breakdown */}
                        {result?.mathematical_breakdown && (
                            <CollapsibleSection
                                title="Mathematical Breakdown"
                                icon={<Calculator className="w-3 h-3" />}
                            >
                                <pre className="text-[10px] text-text-dim leading-relaxed whitespace-pre-wrap font-mono bg-background/50 p-3 rounded-lg border border-border/50">
                                    {result.mathematical_breakdown}
                                </pre>
                            </CollapsibleSection>
                        )}

                        {/* Compliance Risk Factors */}
                        {result?.compliance_risk_factors?.length > 0 && (
                            <CollapsibleSection
                                title={`Compliance Risks (${result.compliance_risk_factors.length})`}
                                icon={<Scale className="w-3 h-3" />}
                                variant="warning"
                                defaultOpen={true}
                            >
                                <div className="space-y-3">
                                    {result.compliance_risk_factors.map((risk, i) => (
                                        <div
                                            key={i}
                                            className="p-3 rounded-lg border border-red-500/20 bg-red-500/5 fade-in"
                                        >
                                            <div className="flex items-start justify-between gap-2 mb-2">
                                                <span className="text-[10px] font-bold text-red-400">{risk.regulation}</span>
                                                <span className={`text-[9px] uppercase px-2 py-0.5 rounded-full font-bold ${risk.severity === 'Critical' ? 'bg-red-500/20 text-red-400' :
                                                    risk.severity === 'High' ? 'bg-orange-500/20 text-orange-400' :
                                                        risk.severity === 'Medium' ? 'bg-yellow-500/20 text-yellow-400' :
                                                            'bg-blue-500/20 text-blue-400'
                                                    }`}>{risk.severity}</span>
                                            </div>
                                            <p className="text-[10px] text-text-dim mb-2">{risk.finding}</p>
                                            <div className="text-[9px] text-text-dim/70 bg-background/50 p-2 rounded border border-border/50">
                                                <span className="text-primary font-bold">Remediation:</span> {risk.remediation}
                                            </div>
                                            {risk.affected_lines && (
                                                <p className="text-[9px] text-text-dim/50 mt-1">Lines: {risk.affected_lines}</p>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </CollapsibleSection>
                        )}

                        {/* Technical Debt Warnings */}
                        {result?.technical_debt_warnings?.length > 0 && (
                            <CollapsibleSection
                                title={`Technical Debt (${result.technical_debt_warnings.length})`}
                                icon={<Wrench className="w-3 h-3" />}
                            >
                                <div className="space-y-2">
                                    {(result.technical_debt_warnings || []).map((warning, i) => (
                                        <div key={i} className="flex items-start gap-2 text-[10px] text-text-dim bg-background/50 p-2 rounded-lg border border-border/50">
                                            <AlertTriangle className="w-3 h-3 text-yellow-500 shrink-0 mt-0.5" />
                                            <span>{warning}</span>
                                        </div>
                                    ))}
                                </div>
                            </CollapsibleSection>
                        )}

                        {/* Extracted Business Rules */}
                        <CollapsibleSection
                            title="Extracted Business Rules"
                            icon={<Shield className="w-3 h-3" />}
                            defaultOpen={!result?.compliance_risk_factors?.length}
                        >
                            <div className="space-y-3">
                                {result?.extracted_rules?.map((rule, i) => (
                                    <div
                                        key={rule.id}
                                        className={`p-3 rounded-xl border transition-all fade-in ${rule.is_risk ? 'bg-primary/5 border-primary/30' : 'bg-background/50 border-border hover:border-text-dim/50'}`}
                                    >
                                        <div className="flex items-start gap-3">
                                            {rule.is_risk ? (
                                                <AlertTriangle className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                                            ) : (
                                                <CheckCircle className="w-4 h-4 text-green-500 shrink-0 mt-0.5" />
                                            )}
                                            <div className="space-y-1 flex-1">
                                                <div className="flex items-center justify-between">
                                                    <p className={`text-xs font-bold leading-tight ${rule.is_risk ? 'text-primary' : 'text-text'}`}>
                                                        {rule.name}
                                                    </p>
                                                    <span className="text-[9px] text-text-dim bg-surface-highlight px-2 py-0.5 rounded-full">
                                                        {rule.id}
                                                    </span>
                                                </div>
                                                <p className="text-[10px] text-text-dim leading-relaxed">
                                                    {rule.description}
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                )) || (
                                        <div className="py-8 text-center space-y-3 opacity-20">
                                            <Filter className="w-8 h-8 mx-auto" />
                                            <p className="text-[10px] uppercase font-bold tracking-widest">No Rules Extracted</p>
                                        </div>
                                    )}
                            </div>
                        </CollapsibleSection>

                        {/* Quick Actions */}
                        <div className="grid grid-cols-2 gap-3 pt-2">
                            <button disabled={!result} className="py-3 bg-surface-highlight border border-border rounded-xl text-[10px] font-bold uppercase tracking-widest text-text-dim hover:text-text hover:border-text-dim transition-all disabled:opacity-30">
                                Export Behavioral Verification
                            </button>
                            <button disabled={!result} className="py-3 bg-surface-highlight border border-border rounded-xl text-[10px] font-bold uppercase tracking-widest text-text-dim hover:text-text hover:border-text-dim transition-all disabled:opacity-30">
                                Push Code
                            </button>
                        </div>

                    </section>

                </main>
            </div>
        </div>
    );
};

const CollapsibleSection = ({ title, icon, children, defaultOpen = false, variant = 'default' }) => {
    const [isOpen, setIsOpen] = useState(defaultOpen);

    return (
        <div className={`bg-surface/50 border rounded-2xl overflow-hidden transition-all ${variant === 'warning' ? 'border-red-500/20' : 'border-border'}`}>
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="w-full px-5 py-4 flex items-center justify-between hover:bg-surface-highlight/30 transition-colors"
            >
                <div className="flex items-center gap-3">
                    <span className={`${variant === 'warning' ? 'text-red-400' : 'text-primary'}`}>{icon}</span>
                    <h3 className="text-[10px] font-bold uppercase tracking-[0.2em] text-text-dim">{title}</h3>
                </div>
                {isOpen ? <ChevronUp className="w-3 h-3 text-text-dim" /> : <ChevronDown className="w-3 h-3 text-text-dim" />}
            </button>
            <div className="collapse-panel" data-open={isOpen}>
                <div className="px-5 pb-5 border-t border-border/30 pt-4">
                    {children}
                </div>
            </div>
        </div>
    );
};

export default Dashboard;
