import { useState, useEffect } from 'react';
import { Shield, Lock, Building, Globe, MapPin, Briefcase, Mail, ChevronRight } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { useAuth } from '../context/AuthContext';
import { apiUrl } from '../config/api';
import Logo from '../components/Logo';

const LoginPage = () => {
    const [isLogin, setIsLogin] = useState(true);
    const [isPending, setIsPending] = useState(false);
    const [justRegistered, setJustRegistered] = useState(false);
    const [formData, setFormData] = useState({
        username: '',
        password: '',
        email: '',
        institution: '',
        city: '',
        country: '',
        role: ''
    });
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const { theme } = useTheme();
    const auth = useAuth();

    // ═════════════════════════════════════════════════════════════════════════
    // LOOP-BREAKER: If token exists but we're on login, don't render login UI
    // This prevents "infinite check" when 401 clears token but page hasn't unmounted
    // ═════════════════════════════════════════════════════════════════════════
    useEffect(() => {
        // If user is already authenticated, App.jsx handles routing
    }, [auth.isInitialized, auth.isAuthenticated]);

    const handleInputChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
        setError('');
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');

        const endpoint = isLogin ? '/auth/login' : '/auth/register';

        auth.logAuthEvent('LOGIN-ATTEMPT', {
            endpoint,
            username: formData.username,
        });

        try {
            const response = await fetch(apiUrl(endpoint), {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData),
                credentials: 'include',
            });

            let data;
            try {
                data = await response.json();
            } catch (jsonErr) {
                const text = await response.text();
                throw new Error(text || `Server Error ${response.status}`);
            }

            auth.logAuthEvent('LOGIN-RESPONSE', {
                endpoint,
                status: response.status,
                hasToken: !!data.access_token,
            });

            if (!response.ok) {
                if (response.status === 403 && data.detail?.includes("Pending Approval")) {
                    auth.logAuthEvent('LOGIN-PENDING', {
                        message: 'Account pending approval',
                    });
                    setIsPending(true);
                    setLoading(false);
                    return;
                }
                const errorMsg = typeof data.detail === 'string'
                    ? data.detail
                    : (Array.isArray(data.detail) ? (data.detail[0]?.msg || JSON.stringify(data.detail)) : JSON.stringify(data.detail));
                
                auth.logAuthEvent('LOGIN-FAILED', {
                    status: response.status,
                    error: errorMsg,
                });
                throw new Error(errorMsg || 'Authentication failed');
            }

            if (isLogin) {
                // ═════════════════════════════════════════════════════════════════
                // HARD OVERRIDE: Save token to localStorage and do hard page refresh
                // This completely bypasses React state sync issues
                // ═════════════════════════════════════════════════════════════════
                auth.logAuthEvent('LOGIN-SUCCESS', {
                    username: formData.username,
                    corporateId: data.corporate_id,
                    isApproved: data.is_approved,
                });

                // CRITICAL: Synchronous localStorage write
                localStorage.setItem('alethia_token', data.access_token);
                localStorage.setItem('corporate_id', data.corporate_id || '');

                // HARD REFRESH: Full browser reload to clear all memory states
                window.location.href = '/';
                return;
            } else {
                auth.logAuthEvent('REGISTRATION-SUCCESS', {
                    username: formData.username,
                    message: 'Registration successful - awaiting approval',
                });
                setJustRegistered(true);
                setIsLogin(true);
                setFormData(prev => ({ ...prev, password: '', email: '' }));
                setLoading(false);
            }
        } catch (err) {
            auth.logAuthEvent('LOGIN-EXCEPTION', {
                error: err.message,
            });
            setError(err.message);
            setLoading(false);
        }
    };

    if (isPending) {
        return (
            <div className="min-h-screen bg-background flex flex-col items-center justify-center p-6 text-center">
                <div
                    className="w-full max-w-2xl bg-surface/40 backdrop-blur-3xl border border-primary/30 rounded-3xl p-12 fade-in"
                >
                    <div className="w-20 h-20 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-8">
                        <Shield className="text-primary w-10 h-10" />
                    </div>
                    <h2 className="text-2xl font-mono font-bold tracking-widest text-text mb-6 uppercase">
                        Security Review in Progress
                    </h2>
                    <p className="text-text-dim mb-8 max-w-md mx-auto leading-relaxed">
                        Access to the Alethia Engine is restricted to verified institutions. Our security architects are currently validating your institutional credentials.
                    </p>
                    <button
                        onClick={() => setIsPending(false)}
                        className="text-xs text-primary hover:text-white transition-colors underline underline-offset-8 uppercase tracking-widest"
                    >
                        Return to Authentication
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-background flex items-center justify-center p-6 relative overflow-hidden font-sans">
            <div className="w-full max-w-[480px] z-10 fade-in">
                <div className="flex justify-center mb-8">
                    <Logo
                        className="w-16 h-16 cursor-pointer hover:opacity-80 transition-opacity"
                        theme={theme}
                        onClick={() => window.location.reload()}
                    />
                </div>
                <h1 className="text-xl font-mono tracking-[0.2em] text-text uppercase text-center mb-10">
                    {isLogin ? 'Vault Access' : 'Institution Registry'}
                </h1>

                <div className="flex items-center justify-center gap-2 mb-4">
                    <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                    <span className="text-[9px] font-mono tracking-widest text-green-500/80 uppercase">Alethia Engine: Online</span>
                </div>

                <div className="bg-surface/40 backdrop-blur-2xl border border-border rounded-3xl p-8 shadow-2xl relative overflow-hidden">
                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div className="space-y-4">
                            <div className="relative group">
                                <Shield className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim group-focus-within:text-primary transition-colors" size={18} />
                                <input
                                    type="text"
                                    name="username"
                                    placeholder="CORPORATE ID"
                                    required
                                    className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                    value={formData.username}
                                    onChange={handleInputChange}
                                />
                            </div>

                            {!isLogin && (
                                <div className="space-y-4 pt-2 fade-in">
                                    <div className="relative group">
                                        <Building className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" size={18} />
                                        <input
                                            type="text"
                                            name="institution"
                                            placeholder="FULL INSTITUTION NAME"
                                            required
                                            className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                            value={formData.institution}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                    <div className="grid grid-cols-2 gap-4">
                                        <div className="relative group">
                                            <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" size={18} />
                                            <input
                                                type="text"
                                                name="city"
                                                placeholder="CITY"
                                                required
                                                className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                                value={formData.city}
                                                onChange={handleInputChange}
                                            />
                                        </div>
                                        <div className="relative group">
                                            <Globe className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" size={18} />
                                            <input
                                                type="text"
                                                name="country"
                                                placeholder="COUNTRY"
                                                required
                                                className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                                value={formData.country}
                                                onChange={handleInputChange}
                                            />
                                        </div>
                                    </div>
                                    <div className="relative group">
                                        <Briefcase className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" size={18} />
                                        <input
                                            type="text"
                                            name="role"
                                            placeholder="ARCHITECT ROLE"
                                            required
                                            className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                            value={formData.role}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                    <div className="relative group">
                                        <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim" size={18} />
                                        <input
                                            type="email"
                                            name="email"
                                            placeholder="EMAIL (OPTIONAL)"
                                            className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                            value={formData.email}
                                            onChange={handleInputChange}
                                        />
                                    </div>
                                </div>
                            )}

                            <div className="relative group">
                                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-text-dim group-focus-within:text-primary transition-colors" size={18} />
                                <input
                                    type="password"
                                    name="password"
                                    placeholder="SECURITY PASSCODE"
                                    required
                                    className="w-full bg-background/50 border border-border/50 rounded-xl py-4 pl-12 pr-4 text-sm focus:outline-none focus:border-primary/50 transition-all font-mono tracking-wider"
                                    value={formData.password}
                                    onChange={handleInputChange}
                                />
                            </div>
                        </div>

                        {justRegistered && (
                            <div className="bg-green-500/20 border border-green-500/40 text-green-400 text-xs font-mono py-4 px-6 rounded-xl text-center shadow-lg fade-in">
                                <div className="font-bold mb-1 uppercase">Registration Successful</div>
                                Your credentials are under institutional review. Sign in once approved.
                            </div>
                        )}

                        {error && (
                            <div className="bg-red-500/20 border border-red-500/40 text-red-400 text-xs font-mono py-4 px-6 rounded-xl text-center shadow-lg fade-in">
                                <div className="font-bold mb-1 underline uppercase">Invalid Credentials</div>
                                {error}
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-primary text-black font-mono font-bold tracking-[0.2em] py-4 rounded-xl hover:bg-white transition-all shadow-xl flex items-center justify-center gap-2 uppercase text-sm mt-6"
                        >
                            {loading ? (
                                <div className="w-5 h-5 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                            ) : (
                                <>
                                    {isLogin ? 'Enter the Vault' : 'Request Access'}
                                    <ChevronRight size={18} />
                                </>
                            )}
                        </button>
                    </form>

                    <div className="mt-8 text-center">
                        <button
                            onClick={() => { setIsLogin(!isLogin); setError(''); }}
                            className="text-[10px] text-text-dim hover:text-primary transition-colors uppercase tracking-[0.2em] flex items-center justify-center gap-2 mx-auto"
                        >
                            {isLogin ? "No institutional access? Register" : "Already registered? Access Vault"}
                        </button>
                    </div>

                    <div className="mt-8 text-center">
                        <span className="text-[10px] font-mono tracking-[0.3em] text-text-dim/40 uppercase">
                            Alethia Enterprise Protocol v2.5.0
                        </span>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default LoginPage;
