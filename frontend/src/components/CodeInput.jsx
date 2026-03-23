import { useRef, useState } from 'react';
import { Upload } from 'lucide-react';

const CodeInput = ({ value, onChange, onFileSelect, fileName, placeholder, language = 'COBOL' }) => {
    const fileRef = useRef(null);
    const [dragOver, setDragOver] = useState(false);

    const handleFile = (file) => {
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (e) => {
            onChange(e.target.result);
            if (onFileSelect) onFileSelect(file.name);
        };
        reader.readAsText(file);
    };

    const handleDrop = (e) => {
        e.preventDefault();
        setDragOver(false);
        const file = e.dataTransfer.files[0];
        if (file) handleFile(file);
    };

    return (
        <div className="space-y-3">
            <div className="flex items-center gap-3">
                <button
                    type="button"
                    onClick={() => fileRef.current?.click()}
                    className="flex items-center gap-2 px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                    style={{ borderColor: '#1B2A4A', color: '#1B2A4A' }}
                >
                    <Upload size={14} strokeWidth={1.5} />
                    Upload {language} File
                </button>
                {fileName && (
                    <span className="text-[11px] tracking-[0.1em] font-mono" style={{ color: '#6B7280' }}>
                        {fileName}
                    </span>
                )}
                <input
                    ref={fileRef}
                    type="file"
                    accept=".cbl,.cob,.jcl,.json,.txt"
                    className="hidden"
                    onChange={(e) => handleFile(e.target.files[0])}
                />
            </div>
            <div
                onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                onDragLeave={() => setDragOver(false)}
                onDrop={handleDrop}
                className="relative"
            >
                <textarea
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    placeholder={placeholder || `Paste ${language} source here...`}
                    className="w-full h-64 p-4 font-mono text-[12px] leading-relaxed border resize-y focus:outline-none transition-all duration-150"
                    style={{
                        borderColor: dragOver ? '#1B2A4A' : '#E5E7EB',
                        backgroundColor: dragOver ? '#F8F9FA' : '#FFFFFF',
                        color: '#1A1A2E',
                    }}
                    spellCheck={false}
                />
                {dragOver && (
                    <div className="absolute inset-0 flex items-center justify-center bg-white/80 pointer-events-none">
                        <span className="text-[11px] tracking-[0.15em] uppercase font-semibold" style={{ color: '#1B2A4A' }}>
                            Drop file here
                        </span>
                    </div>
                )}
            </div>
        </div>
    );
};

export default CodeInput;
