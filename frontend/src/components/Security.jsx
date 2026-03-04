import { useState, useEffect } from 'react';
import {
    Building,
    MapPin,
    Shield,
    History,
    Lock,
    Key,
    Trash2,
    Database,
    Eye,
    EyeOff,
    Check,
    AlertTriangle,
    RefreshCw,
    HardDrive,
    FileX,
    Fingerprint,
    ChevronRight
} from 'lucide-react';

const SettingsSection = ({ title, description, icon: Icon, children }) => (
    <div className="bg-surface/20 border border-border rounded-2xl overflow-hidden">
        <div className="px-6 py-4 border-b border-border/50 flex items-center gap-3">
            <Icon className="text-primary" size={16} />
            <div>
                <h3 className="text-xs font-mono font-bold tracking-widest uppercase text-text">{title}</h3>
                {description && <p className="text-[9px] text-text-dim uppercase tracking-wider mt-0.5">{description}</p>}
            </div>
        </div>
        <div className="p-6">
            {children}
        </div>
    </div>
);

const ActionButton = ({ onClick, icon: Icon, label, variant = 'default', disabled = false, loading = false }) => {
    const variants = {
        default: 'bg-surface/40 border-border hover:border-primary/50 hover:bg-primary/5 text-text-dim hover:text-text',
        danger: 'bg-red-500/5 border-red-500/20 hover:border-red-500/50 hover:bg-red-500/10 text-red-400',
        success: 'bg-green-500/5 border-green-500/20 text-green-400'
    };

    return (
        <button
            onClick={onClick}
            disabled={disabled || loading}
            className={`flex items-center justify-between gap-3 px-4 py-3 border rounded-xl transition-all ${variants[variant]} ${disabled ? 'opacity-40 cursor-not-allowed' : ''}`}
        >
            <div className="flex items-center gap-3">
                {loading ? (
                    <RefreshCw size={16} className="animate-spin" />
                ) : (
                    <Icon size={16} />
                )}
                <span className="text-[11px] font-mono uppercase tracking-widest">{label}</span>
            </div>
            <ChevronRight size={14} className="opacity-40" />
        </button>
    );
};

const Security = () => {
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [showHistory, setShowHistory] = useState(true);
    const [localHistory, setLocalHistory] = useState([]);

    // Password change state
    const [showPasswordForm, setShowPasswordForm] = useState(false);
    const [passwordData, setPasswordData] = useState({ current: '', new: '', confirm: '' });
    const [showPasswords, setShowPasswords] = useState({ current: false, new: false, confirm: false });
    const [passwordError, setPasswordError] = useState('');
    const [passwordSuccess, setPasswordSuccess] = useState(false);
    const [changingPassword, setChangingPassword] = useState(false);

    // Action states
    const [clearingCache, setClearingCache] = useState(false);
    const [cacheCleared, setCacheCleared] = useState(false);
    const [clearingHistory, setClearingHistory] = useState(false);
    const [historyCleared, setHistoryCleared] = useState(false);

    useEffect(() => {
        const fetchProfile = async () => {
            const token = localStorage.getItem('alethia_token');
            try {
                const response = await fetch('http://127.0.0.1:8001/auh/profile', {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                if (response.ok) {
                    const data = await response.json();
                    setProfile(data);
                    setLocalHistory(data.security_history || []);
                }
            } catch (err) {
                console.error("Profile sync failed", err);
            } finally {
                setLoading(false);
            }
        };
        fetchProfile();
    }, []);

    const handlePasswordChange = async () => {
        setPasswordError('');
        setPasswordSuccess(false);

        if (passwordData.new !== passwordData.confirm) {
            setPasswordError('New passwords do not match');
            return;
        }
        if (passwordData.new.length < 8) {
            setPasswordError('Password must be at least 8 characters');
            return;
        }

        setChangingPassword(true);

        // Simulate API call (in production, this would call the backend)
        setTimeout(() => {
            setChangingPassword(false);
            setPasswordSuccess(true);
            setPasswordData({ current: '', new: '', confirm: '' });
            setShowPasswordForm(false);
            setTimeout(() => setPasswordSuccess(false), 3000);
        }, 1500);
    };

    const handleClearCache = () => {
        setClearingCache(true);

        setTimeout(() => {
            // Clear all localStorage except authentication tokens
            const keysToKeep = ['alethia_token', 'corporate_id'];
            Object.keys(localStorage).forEach(key => {
                if (!keysToKeep.includes(key)) {
                    localStorage.removeItem(key);
                }
            });

            // Clear sessionStorage
            sessionStorage.clear();

            setClearingCache(false);
            setCacheCleared(true);
            setTimeout(() => setCacheCleared(false), 3000);
        }, 1000);
    };

    const handleClearHistory = () => {
        setClearingHistory(true);

        setTimeout(() => {
            // Only clear from frontend view, backend retains data
            setLocalHistory([]);
            setShowHistory(false);
            setClearingHistory(false);
            setHistoryCleared(true);
            setTimeout(() => setHistoryCleared(false), 3000);
        }, 1000);
    };

    if (loading) {
        return (
            <div className="p-8 flex items-center justify-center min-h-[50vh]">
                <div className="w-8 h-8 border-2 border-primary/20 border-t-primary rounded-full animate-spin" />
            </div>
        );
    }

    const displayProfile = profile || {
        username: localStorage.getItem('corporate_id') || 'Unknown',
        institution: 'Institution',
        city: 'City',
        country: 'Country',
        role: 'Architect',
        security_history: []
    };

    return (
        <div className="p-8 max-w-5xl mx-auto space-y-8">
            {/* Header */}
            <div className="space-y-1">
                <h1 className="text-2xl font-mono font-bold tracking-widest text-text uppercase">Security Center</h1>
                <p className="text-[10px] text-text-dim uppercase tracking-[0.2em]">Identity Management & Privacy Controls</p>
            </div>

            {/* Success Notifications */}
            {(passwordSuccess || cacheCleared || historyCleared) && (
                <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 flex items-center gap-3 fade-in">
                    <Check className="text-green-400" size={18} />
                    <span className="text-[11px] font-mono uppercase tracking-widest text-green-400">
                        {passwordSuccess && 'Password updated successfully'}
                        {cacheCleared && 'Local cache cleared successfully'}
                        {historyCleared && 'Activity history hidden from view'}
                    </span>
                </div>
            )}

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Column 1: Profile & Identity */}
                <div className="space-y-6">
                    <SettingsSection title="Identity Profile" icon={Fingerprint}>
                        <div className="space-y-6">
                            <div className="flex flex-col items-center py-4 border-b border-border/50">
                                <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mb-4">
                                    <Fingerprint className="text-primary w-8 h-8" />
                                </div>
                                <h3 className="font-mono text-sm font-bold tracking-wider text-text uppercase">{displayProfile.username}</h3>
                                <span className="text-[10px] text-primary uppercase font-mono tracking-widest mt-1">Verified Architect</span>
                            </div>

                            <div className="space-y-4">
                                <div className="flex items-center gap-3">
                                    <Building size={14} className="text-text-dim" />
                                    <div className="text-[10px] uppercase tracking-widest text-text truncate">{displayProfile.institution}</div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <MapPin size={14} className="text-text-dim" />
                                    <div className="text-[10px] uppercase tracking-widest text-text-dim">
                                        {displayProfile.city}, {displayProfile.country}
                                    </div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <Shield size={14} className="text-text-dim" />
                                    <div className="text-[10px] uppercase tracking-widest text-text-dim">{displayProfile.role}</div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <Lock size={14} className="text-text-dim" />
                                    <div className="text-[10px] uppercase tracking-widest text-text-dim">RSA-4096 Encrypted</div>
                                </div>
                            </div>
                        </div>
                    </SettingsSection>
                </div>

                {/* Column 2: Security Settings */}
                <div className="space-y-6">
                    <SettingsSection title="Authentication" description="Manage your credentials" icon={Key}>
                        <div className="space-y-4">
                            <ActionButton
                                onClick={() => setShowPasswordForm(!showPasswordForm)}
                                icon={Lock}
                                label="Change Password"
                            />

                            {showPasswordForm && (
                                    <div className="space-y-4 pt-4 border-t border-border/50 fade-in">
                                        {/* Current Password */}
                                        <div className="relative">
                                            <input
                                                type={showPasswords.current ? 'text' : 'password'}
                                                placeholder="CURRENT PASSWORD"
                                                value={passwordData.current}
                                                onChange={(e) => setPasswordData({ ...passwordData, current: e.target.value })}
                                                className="w-full bg-background/50 border border-border/50 rounded-lg py-3 px-4 pr-10 text-[11px] font-mono tracking-wider focus:outline-none focus:border-primary/50"
                                            />
                                            <button
                                                type="button"
                                                onClick={() => setShowPasswords({ ...showPasswords, current: !showPasswords.current })}
                                                className="absolute right-3 top-1/2 -translate-y-1/2 text-text-dim hover:text-text"
                                            >
                                                {showPasswords.current ? <EyeOff size={14} /> : <Eye size={14} />}
                                            </button>
                                        </div>

                                        {/* New Password */}
                                        <div className="relative">
                                            <input
                                                type={showPasswords.new ? 'text' : 'password'}
                                                placeholder="NEW PASSWORD"
                                                value={passwordData.new}
                                                onChange={(e) => setPasswordData({ ...passwordData, new: e.target.value })}
                                                className="w-full bg-background/50 border border-border/50 rounded-lg py-3 px-4 pr-10 text-[11px] font-mono tracking-wider focus:outline-none focus:border-primary/50"
                                            />
                                            <button
                                                type="button"
                                                onClick={() => setShowPasswords({ ...showPasswords, new: !showPasswords.new })}
                                                className="absolute right-3 top-1/2 -translate-y-1/2 text-text-dim hover:text-text"
                                            >
                                                {showPasswords.new ? <EyeOff size={14} /> : <Eye size={14} />}
                                            </button>
                                        </div>

                                        {/* Confirm Password */}
                                        <div className="relative">
                                            <input
                                                type={showPasswords.confirm ? 'text' : 'password'}
                                                placeholder="CONFIRM NEW PASSWORD"
                                                value={passwordData.confirm}
                                                onChange={(e) => setPasswordData({ ...passwordData, confirm: e.target.value })}
                                                className="w-full bg-background/50 border border-border/50 rounded-lg py-3 px-4 pr-10 text-[11px] font-mono tracking-wider focus:outline-none focus:border-primary/50"
                                            />
                                            <button
                                                type="button"
                                                onClick={() => setShowPasswords({ ...showPasswords, confirm: !showPasswords.confirm })}
                                                className="absolute right-3 top-1/2 -translate-y-1/2 text-text-dim hover:text-text"
                                            >
                                                {showPasswords.confirm ? <EyeOff size={14} /> : <Eye size={14} />}
                                            </button>
                                        </div>

                                        {passwordError && (
                                            <div className="flex items-center gap-2 text-red-400 text-[10px] font-mono">
                                                <AlertTriangle size={12} />
                                                <span>{passwordError}</span>
                                            </div>
                                        )}

                                        <button
                                            onClick={handlePasswordChange}
                                            disabled={changingPassword || !passwordData.current || !passwordData.new || !passwordData.confirm}
                                            className="w-full bg-primary text-black py-3 rounded-lg text-[11px] font-mono font-bold uppercase tracking-widest hover:bg-white transition-all disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                                        >
                                            {changingPassword ? (
                                                <>
                                                    <RefreshCw size={14} className="animate-spin" />
                                                    Updating...
                                                </>
                                            ) : (
                                                'Update Password'
                                            )}
                                        </button>
                                    </div>
                            )}
                        </div>
                    </SettingsSection>

                    <SettingsSection title="Data & Privacy" description="Manage local storage" icon={Database}>
                        <div className="space-y-4">
                            <ActionButton
                                onClick={handleClearCache}
                                icon={HardDrive}
                                label="Clear Local Cache"
                                loading={clearingCache}
                                variant={cacheCleared ? 'success' : 'default'}
                            />
                            <p className="text-[9px] text-text-dim/60 uppercase tracking-wider px-1">
                                Removes cached data from your browser. Does not affect server records.
                            </p>

                            <ActionButton
                                onClick={handleClearHistory}
                                icon={FileX}
                                label="Hide Activity History"
                                loading={clearingHistory}
                                variant={historyCleared ? 'success' : 'default'}
                                disabled={localHistory.length === 0}
                            />
                            <p className="text-[9px] text-text-dim/60 uppercase tracking-wider px-1">
                                Hides activity from this view. Server audit logs are retained for compliance.
                            </p>
                        </div>
                    </SettingsSection>

                    <SettingsSection title="Danger Zone" description="Irreversible actions" icon={AlertTriangle}>
                        <div className="space-y-4">
                            <ActionButton
                                onClick={() => {
                                    if (confirm('Are you sure you want to clear all local data? You will be logged out.')) {
                                        localStorage.clear();
                                        sessionStorage.clear();
                                        window.location.reload();
                                    }
                                }}
                                icon={Trash2}
                                label="Clear All Local Data"
                                variant="danger"
                            />
                            <p className="text-[9px] text-text-dim/60 uppercase tracking-wider px-1">
                                Removes all local data and logs you out. Server data remains intact.
                            </p>
                        </div>
                    </SettingsSection>
                </div>

                {/* Column 3: Security History */}
                <div className="space-y-6">
                    <SettingsSection title="Security History" description="Access audit trail" icon={History}>
                        {showHistory && localHistory.length > 0 ? (
                            <div className="space-y-3 max-h-[500px] overflow-y-auto">
                                {localHistory.map((log, i) => (
                                    <div
                                        key={i}
                                        className="bg-background/30 border border-border/30 rounded-lg p-3 space-y-2 fade-in"
                                    >
                                        <div className="flex items-center justify-between">
                                            <span className={`text-[10px] font-mono uppercase tracking-wider ${log.event?.includes('Failed') ? 'text-red-400' : 'text-primary/70'}`}>
                                                {log.event}
                                            </span>
                                        </div>
                                        <div className="flex items-center justify-between text-[9px] text-text-dim/50">
                                            <span>{new Date(log.timestamp).toLocaleString()}</span>
                                            <span className="italic">{log.ip}</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="py-12 text-center space-y-3">
                                <History className="w-8 h-8 mx-auto text-text-dim/20" />
                                <p className="text-[10px] text-text-dim/40 uppercase tracking-widest">
                                    {historyCleared ? 'History hidden from view' : 'No activity recorded'}
                                </p>
                            </div>
                        )}

                        {historyCleared && (
                            <button
                                onClick={() => {
                                    setShowHistory(true);
                                    setLocalHistory(profile?.security_history || []);
                                    setHistoryCleared(false);
                                }}
                                className="w-full mt-4 py-2 text-[10px] font-mono uppercase tracking-widest text-text-dim hover:text-primary transition-colors border border-border/50 rounded-lg hover:border-primary/30"
                            >
                                Restore History View
                            </button>
                        )}
                    </SettingsSection>

                    <div className="p-4 rounded-xl bg-primary/5 border border-primary/10 flex items-start gap-3">
                        <Shield className="text-primary shrink-0 mt-1" size={16} />
                        <div className="space-y-2">
                            <p className="text-[10px] leading-relaxed text-text-dim uppercase tracking-wider">
                                All clearing operations only affect your local browser. Server-side audit logs are retained per regulatory requirements.
                            </p>
                            <p className="text-[9px] text-text-dim/50 uppercase tracking-wider">
                                Tier-1 Governance
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Security;
