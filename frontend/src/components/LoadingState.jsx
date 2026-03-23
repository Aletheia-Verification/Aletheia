const LoadingState = ({ label = 'Processing...' }) => (
    <div className="flex flex-col items-center justify-center py-16">
        <div
            className="w-10 h-10 border-2 border-t-transparent animate-spin mb-4"
            style={{ borderColor: '#E5E7EB', borderTopColor: '#1B2A4A' }}
        />
        <p className="text-[11px] tracking-[0.15em] uppercase font-mono" style={{ color: '#6B7280' }}>
            {label}
        </p>
    </div>
);

export default LoadingState;
