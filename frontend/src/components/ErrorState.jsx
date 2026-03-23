import { AlertTriangle } from 'lucide-react';

const ErrorState = ({ message, onRetry }) => (
    <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle size={28} strokeWidth={1.5} style={{ color: '#DC2626' }} className="mb-4" />
        <p className="text-[12px] tracking-[0.1em] mb-4 text-center max-w-md" style={{ color: '#DC2626' }}>
            {message || 'An error occurred. Please try again.'}
        </p>
        {onRetry && (
            <button
                onClick={onRetry}
                className="px-4 py-2 text-[10px] tracking-[0.12em] uppercase font-semibold border transition-all duration-150 hover:shadow-sm"
                style={{ borderColor: '#1B2A4A', color: '#1B2A4A' }}
            >
                Retry
            </button>
        )}
    </div>
);

export default ErrorState;
