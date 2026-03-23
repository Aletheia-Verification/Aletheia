import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowRight, Shield, FileCheck, Cpu } from 'lucide-react';
import Logo from '../components/Logo';

const G = '#1B2A4A';  // navy (primary)
const BG = '#FFFFFF';
const CARD = '#F8F9FA';
const TEXT = '#1A1A2E';
const MUTED = '#6B7280';
const BORDER = '#E5E7EB';

const fade = { initial: { opacity: 0, y: 20 }, whileInView: { opacity: 1, y: 0 }, viewport: { once: true, margin: '-50px' }, transition: { duration: 0.5 } };

const Stat = ({ value, label }) => (
    <div className="text-center px-4 py-6">
        <div className="text-3xl md:text-4xl font-mono font-bold tracking-tight" style={{ color: G }}>{value}</div>
        <div className="text-[10px] uppercase tracking-[0.2em] mt-2" style={{ color: MUTED }}>{label}</div>
    </div>
);

const Step = ({ number, title, description, icon: Icon }) => (
    <div className="flex-1 p-6 border text-center" style={{ borderColor: BORDER, backgroundColor: CARD }}>
        <div className="w-10 h-10 mx-auto mb-4 flex items-center justify-center border" style={{ borderColor: G, color: G }}>
            <span className="font-mono text-sm font-bold">{number}</span>
        </div>
        <Icon size={20} strokeWidth={1.5} className="mx-auto mb-3" style={{ color: MUTED }} />
        <h3 className="text-sm font-semibold uppercase tracking-[0.15em] mb-2" style={{ color: TEXT }}>{title}</h3>
        <p className="text-[12px] leading-relaxed" style={{ color: MUTED }}>{description}</p>
    </div>
);

const RoleCard = ({ title, description }) => (
    <div className="flex-1 p-6 border" style={{ borderColor: BORDER, backgroundColor: CARD }}>
        <h3 className="text-xs font-semibold uppercase tracking-[0.15em] mb-2" style={{ color: TEXT }}>{title}</h3>
        <p className="text-[12px] leading-relaxed" style={{ color: MUTED }}>{description}</p>
    </div>
);

export default function LandingPage() {
    return (
        <div style={{ backgroundColor: BG, color: TEXT }}>

            {/* ── Hero ── */}
            <section className="min-h-screen flex flex-col items-center justify-center px-6 text-center">
                <motion.div {...fade}>
                    <span className="text-lg font-medium tracking-[0.4em] uppercase mb-8 block" style={{ color: G }}>
                        Aletheia
                    </span>
                    <div className="w-12 mx-auto mb-8" style={{ height: 1, backgroundColor: G }} />
                    <h1 className="text-2xl md:text-4xl font-light tracking-[0.08em] leading-tight max-w-3xl mx-auto mb-6">
                        Your COBOL migration.<br />
                        <span style={{ color: G }}>Deterministically verified against the source.</span>
                    </h1>
                    <p className="text-[13px] md:text-sm leading-relaxed max-w-xl mx-auto" style={{ color: MUTED }}>
                        Deterministic behavioral verification for legacy system modernization.
                        Not AI translation — mathematical proof.
                    </p>
                </motion.div>
            </section>

            {/* ── Problem ── */}
            <section className="py-20 px-6" style={{ borderTop: `1px solid ${BORDER}` }}>
                <motion.div {...fade} className="max-w-5xl mx-auto text-center">
                    <h2 className="text-lg md:text-xl font-light tracking-[0.06em] mb-4">
                        70% of COBOL migrations fail.
                    </h2>
                    <p className="text-[13px] mb-12" style={{ color: MUTED }}>
                        The ones that don't cost 3x the budget. The problem isn't translation — it's verification.
                    </p>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="p-6 border" style={{ borderColor: BORDER, backgroundColor: CARD }}>
                            <div className="text-3xl font-mono font-bold mb-1" style={{ color: G }}>$1.5T</div>
                            <div className="text-[10px] uppercase tracking-[0.15em]" style={{ color: MUTED }}>Global mainframe spend</div>
                        </div>
                        <div className="p-6 border" style={{ borderColor: BORDER, backgroundColor: CARD }}>
                            <div className="text-3xl font-mono font-bold mb-1" style={{ color: G }}>240B</div>
                            <div className="text-[10px] uppercase tracking-[0.15em]" style={{ color: MUTED }}>Lines of COBOL in production</div>
                        </div>
                        <div className="p-6 border" style={{ borderColor: BORDER, backgroundColor: CARD }}>
                            <div className="text-3xl font-mono font-bold mb-1" style={{ color: G }}>70%</div>
                            <div className="text-[10px] uppercase tracking-[0.15em]" style={{ color: MUTED }}>Migration failure rate</div>
                        </div>
                    </div>
                </motion.div>
            </section>

            {/* ── How it works ── */}
            <section className="py-20 px-6" style={{ borderTop: `1px solid ${BORDER}` }}>
                <motion.div {...fade} className="max-w-5xl mx-auto">
                    <h2 className="text-lg md:text-xl font-light tracking-[0.06em] text-center mb-4">
                        How it works
                    </h2>
                    <p className="text-[13px] text-center mb-12" style={{ color: MUTED }}>
                        Three deterministic steps. Zero guesswork.
                    </p>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <Step
                            number="1"
                            icon={Cpu}
                            title="Parse"
                            description="ANTLR4 COBOL85 parser extracts every operation, variable, and control flow path from your source."
                        />
                        <Step
                            number="2"
                            icon={FileCheck}
                            title="Generate"
                            description="Deterministic Python verification model. Decimal precision. IBM arithmetic. No AI hallucination."
                        />
                        <Step
                            number="3"
                            icon={Shield}
                            title="Prove"
                            description="Shadow Diff compares outputs field-by-field against real mainframe data. Exact match or flagged."
                        />
                    </div>
                </motion.div>
            </section>

            {/* ── Metrics ── */}
            <section className="py-16 px-6" style={{ borderTop: `1px solid ${BORDER}`, backgroundColor: CARD }}>
                <motion.div {...fade} className="max-w-4xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-4">
                    <Stat value="1006+" label="Tests passing" />
                    <Stat value="94.3%" label="Program Verification Rate" />
                    <Stat value="459" label="Dense COBOL programs" />
                    <Stat value="118" label="Behavioral edge cases" />
                </motion.div>
            </section>

            {/* ── For who ── */}
            <section className="py-20 px-6" style={{ borderTop: `1px solid ${BORDER}` }}>
                <motion.div {...fade} className="max-w-5xl mx-auto">
                    <h2 className="text-lg md:text-xl font-light tracking-[0.06em] text-center mb-4">
                        Built for the people who can't afford to get it wrong.
                    </h2>
                    <p className="text-[13px] text-center mb-12" style={{ color: MUTED }}>
                        Migration teams at banks, insurers, and system integrators.
                    </p>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <RoleCard
                            title="Migration Teams"
                            description="Prove behavioral equivalence before you cut over. Replace weeks of manual testing with deterministic verification."
                        />
                        <RoleCard
                            title="Compliance Officers"
                            description="Signed verification reports. Immutable audit trail. Every field checked, every result recorded."
                        />
                        <RoleCard
                            title="Engineering Leaders"
                            description="Know exactly which programs are clean and which need manual review. No surprises in production."
                        />
                    </div>
                </motion.div>
            </section>

            {/* ── CTA ── */}
            <section className="py-20 px-6 text-center" style={{ borderTop: `1px solid ${BORDER}` }}>
                <motion.div {...fade}>
                    <h2 className="text-xl md:text-2xl font-light tracking-[0.06em] mb-6">
                        Stop guessing. <span style={{ color: G }}>Start proving.</span>
                    </h2>
                </motion.div>
            </section>

            {/* ── Footer ── */}
            <footer className="py-12 px-6 text-center" style={{ borderTop: `1px solid ${BORDER}` }}>
                <Link
                    to="/analyze"
                    className="inline-flex items-center gap-2 px-10 py-4 text-[11px] uppercase tracking-[0.2em] font-semibold transition-all duration-150 hover:opacity-90 rounded-lg"
                    style={{ backgroundColor: G, color: BG }}
                >
                    Try it free <ArrowRight size={14} strokeWidth={1.5} />
                </Link>
            </footer>
        </div>
    );
}
