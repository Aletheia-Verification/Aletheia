import React from 'react';

class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props);
        this.state = { hasError: false, error: null };
    }

    static getDerivedStateFromError(error) {
        return { hasError: true, error };
    }

    render() {
        if (this.state.hasError) {
            return (
                <div className="min-h-screen flex items-center justify-center p-8" style={{ backgroundColor: '#FFFFFF' }}>
                    <div className="text-center space-y-4 max-w-md">
                        <h2 className="text-lg font-medium" style={{ color: '#1A1A2E' }}>
                            Something went wrong
                        </h2>
                        <p className="text-sm" style={{ color: '#6B7280' }}>
                            {this.state.error?.message || 'An unexpected error occurred.'}
                        </p>
                        <button
                            onClick={() => window.location.reload()}
                            className="px-6 py-2.5 text-sm rounded-lg transition-opacity hover:opacity-90"
                            style={{ backgroundColor: '#1B2A4A', color: 'white' }}
                        >
                            Reload
                        </button>
                    </div>
                </div>
            );
        }
        return this.props.children;
    }
}

export default ErrorBoundary;
