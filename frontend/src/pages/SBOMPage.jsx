import { useState } from 'react';
import { FileJson, Download } from 'lucide-react';
import { authApi } from '../utils/authFetch';
import { useColors, LIGHT } from '../hooks/useColors';
import PageHeader from '../components/PageHeader';
import CodeInput from '../components/CodeInput';
import LoadingState from '../components/LoadingState';
import ErrorState from '../components/ErrorState';

const SBOMPage = () => {
    const C = useColors() || LIGHT;
    const [cobolCode, setCobolCode] = useState('');
    const [fileName, setFileName] = useState('');
    const [sbom, setSbom] = useState(null);
    const [loading, setLoading] = useState(false);
    const [step, setStep] = useState('idle'); // idle | analyzing | generating | done
    const [error, setError] = useState(null);
    const [showRaw, setShowRaw] = useState(false);

    const generate = async () => {
        if (!cobolCode.trim()) return;
        setLoading(true);
        setError(null);
        setSbom(null);

        try {
            // Step 1: Analyze COBOL
            setStep('analyzing');
            const analyzeRes = await authApi.post('/engine/analyze', {
                cobol_code: cobolCode,
                filename: fileName || 'input.cbl',
            });
            if (!analyzeRes.ok) {
                const err = await analyzeRes.json();
                throw new Error(err.detail || 'Analysis failed');
            }
            const analysis = await analyzeRes.json();

            // Step 2: Generate SBOM
            setStep('generating');
            const sbomPayload = {
                program_name: fileName?.replace(/\.(cbl|cob)$/i, '') || 'INPUT',
                copybooks: analysis.copybook_issues || [],
                calls: analysis.calls || [],
                exec_dependencies: analysis.exec_dependencies || [],
                dead_code: analysis.dead_code || {},
            };

            const sbomRes = await authApi.post('/engine/generate-sbom', sbomPayload);
            if (!sbomRes.ok) {
                const err = await sbomRes.json();
                throw new Error(err.detail || 'SBOM generation failed');
            }
            const sbomData = await sbomRes.json();
            setSbom(sbomData);
            setStep('done');
        } catch (e) {
            setError(e.message);
            setStep('idle');
        } finally {
            setLoading(false);
        }
    };

    const downloadJSON = () => {
        if (!sbom) return;
        const blob = new Blob([JSON.stringify(sbom, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${fileName?.replace(/\.(cbl|cob)$/i, '') || 'sbom'}_cyclonedx.json`;
        a.click();
        URL.revokeObjectURL(url);
    };

    const components = sbom?.components || [];

    return (
        <div>
            <PageHeader
                icon={FileJson}
                title="SBOM Generator"
                subtitle="Generate a CycloneDX 1.4 Software Bill of Materials from COBOL source"
            />

            {!sbom && !loading && (
                <div>
                    <CodeInput
                        value={cobolCode}
                        onChange={setCobolCode}
                        onFileSelect={setFileName}
                        fileName={fileName}
                    />
                    <button
                        onClick={generate}
                        disabled={!cobolCode.trim()}
                        className="mt-4 px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90 disabled:opacity-40"
                        style={{ backgroundColor: C.navy }}
                    >
                        Generate SBOM
                    </button>
                </div>
            )}

            {loading && (
                <LoadingState
                    label={step === 'analyzing' ? 'Analyzing COBOL source...' : 'Generating CycloneDX SBOM...'}
                />
            )}
            {error && <ErrorState message={error} onRetry={() => setError(null)} />}

            {sbom && (
                <div>
                    {/* Metadata */}
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-6">
                        <div className="border p-4" style={{ borderColor: C.border }}>
                            <div className="text-[9px] tracking-[0.1em] uppercase" style={{ color: C.faint }}>Format</div>
                            <div className="text-[12px] font-mono font-semibold mt-1" style={{ color: C.text }}>
                                {sbom.bomFormat || 'CycloneDX'} {sbom.specVersion || '1.4'}
                            </div>
                        </div>
                        <div className="border p-4" style={{ borderColor: C.border }}>
                            <div className="text-[9px] tracking-[0.1em] uppercase" style={{ color: C.faint }}>Components</div>
                            <div className="text-[12px] font-mono font-semibold mt-1" style={{ color: C.text }}>
                                {components.length}
                            </div>
                        </div>
                        <div className="border p-4" style={{ borderColor: C.border }}>
                            <div className="text-[9px] tracking-[0.1em] uppercase" style={{ color: C.faint }}>Serial</div>
                            <div className="text-[10px] font-mono mt-1 truncate" style={{ color: C.faint }}>
                                {sbom.serialNumber || '—'}
                            </div>
                        </div>
                    </div>

                    {/* Components Table */}
                    {components.length > 0 && (
                        <div className="border mb-6" style={{ borderColor: C.border }}>
                            <table className="w-full text-left">
                                <thead>
                                    <tr style={{ backgroundColor: '#F8F9FA' }}>
                                        <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Name</th>
                                        <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Type</th>
                                        <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>Group</th>
                                        <th className="px-4 py-3 text-[10px] tracking-[0.1em] uppercase font-semibold" style={{ color: C.faint }}>PURL</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {components.map((c, i) => (
                                        <tr key={i} className="border-t" style={{ borderColor: C.border }}>
                                            <td className="px-4 py-2 text-[11px] font-mono" style={{ color: C.text }}>{c.name}</td>
                                            <td className="px-4 py-2 text-[10px]" style={{ color: C.faint }}>{c.type}</td>
                                            <td className="px-4 py-2 text-[10px]" style={{ color: C.faint }}>{c.group || '—'}</td>
                                            <td className="px-4 py-2 text-[9px] font-mono truncate max-w-[200px]" style={{ color: C.faint }}>
                                                {c.purl || '—'}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}

                    {/* Actions */}
                    <div className="flex gap-3 mb-6">
                        <button
                            onClick={downloadJSON}
                            className="flex items-center gap-2 px-6 py-3 text-[11px] tracking-[0.15em] uppercase font-semibold text-white transition-all duration-150 hover:opacity-90"
                            style={{ backgroundColor: C.navy }}
                        >
                            <Download size={14} strokeWidth={1.5} />
                            Download JSON
                        </button>
                        <button
                            onClick={() => setShowRaw(!showRaw)}
                            className="px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                            style={{ borderColor: C.border, color: C.faint }}
                        >
                            {showRaw ? 'Hide' : 'Show'} Raw JSON
                        </button>
                        <button
                            onClick={() => { setSbom(null); setCobolCode(''); setFileName(''); setStep('idle'); }}
                            className="px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                            style={{ borderColor: C.border, color: C.faint }}
                        >
                            New Analysis
                        </button>
                    </div>

                    {/* Raw JSON */}
                    {showRaw && (
                        <pre
                            className="p-4 text-[10px] font-mono overflow-auto max-h-96 border"
                            style={{ borderColor: C.border, backgroundColor: '#F8F9FA', color: C.text }}
                        >
                            {JSON.stringify(sbom, null, 2)}
                        </pre>
                    )}
                </div>
            )}
        </div>
    );
};

export default SBOMPage;
