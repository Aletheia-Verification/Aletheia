import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useColors, LIGHT } from '../hooks/useColors';

const ProtectedRoute = () => {
    const auth = useAuth();
    const C = useColors() || LIGHT;

    // Gate 0: Auth not yet initialized — show loading spinner
    if (!auth.isInitialized) {
        return (
            <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: C.bg }}>
                <div className="text-center">
                    <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 mb-4" style={{ borderColor: C.navy }} />
                    <p className="font-mono text-sm" style={{ color: C.muted }}>Initializing secure session...</p>
                </div>
            </div>
        );
    }

    // Gate 1: Not authenticated — redirect to login
    if (!auth.isAuthenticated) {
        return <Navigate to="/login" replace />;
    }

    return <Outlet />;
};

export default ProtectedRoute;
