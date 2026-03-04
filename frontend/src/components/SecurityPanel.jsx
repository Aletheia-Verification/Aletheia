import { useState, useEffect } from 'react';
import { X, Shield, Activity, Key, LogOut, User, Download, Upload } from 'lucide-react';
import { apiUrl } from '../config/api';

const SecurityPanel = ({ isOpen, setIsOpen }) => {
    const [activeSection, setActiveSection] = useState('account'); // 'account' | 'activity' | 'password'
    const [activityLog, setActivityLog] = useState([]);
    const [isLoadingActivity, setIsLoadingActivity] = useState(false);
    const [userInfo, setUserInfo] = useState(null);

    // Password change state
    const [currentPassword, setCurrentPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [passwordError, setPasswordError] = useState('');
    const [passwordSuccess, setPasswordSuccess] = useState(false);

    useEffect(() => {
        if (isOpen && !userInfo) {
            loadUserInfo();
        }
        if (isOpen && activeSection === 'activity' && activityLog.length === 0) {
            loadActivityLog();
        }
    }, [isOpen, activeSection]);

    const loadUserInfo = async () => {
        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/auth/profile'), {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setUserInfo(data);
            }
        } catch (error) {
            console.error('Failed to load user info:', error);
        }
    };

    const loadActivityLog = async () => {
        setIsLoadingActivity(true);
        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/auth/profile'), {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setActivityLog(data.security_history || []);
            }
        } catch (error) {
            console.error('Failed to load activity log:', error);
        } finally {
            setIsLoadingActivity(false);
        }
    };

    const handleSignOut = () => {
        localStorage.removeItem('alethia_token');
        window.location.href = '/';
    };

    const handlePasswordChange = async (e) => {
        e.preventDefault();
        setPasswordError('');
        setPasswordSuccess(false);

        if (newPassword !== confirmPassword) {
            setPasswordError('New passwords do not match');
            return;
        }

        if (newPassword.length < 8) {
            setPasswordError('Password must be at least 8 characters');
            return;
        }

        try {
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/auth/change-password'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    current_password: currentPassword,
                    new_password: newPassword
                })
            });

            if (response.ok) {
                setPasswordSuccess(true);
                setCurrentPassword('');
                setNewPassword('');
                setConfirmPassword('');
                loadActivityLog(); // Refresh to show password change event
            } else {
                const data = await response.json();
                setPasswordError(data.detail || 'Failed to change password');
            }
        } catch (error) {
            setPasswordError('Network error. Please try again.');
        }
    };

    const exportActivityLog = () => {
        const csv = [
            'Timestamp,Event,IP Address',
            ...activityLog.map(e =>
                `"${e.timestamp}","${e.event}","${e.ip || 'local'}"`
            )
        ].join('\n');

        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `security-log-${new Date().toISOString().split('T')[0]}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    const getEventIcon = (event) => {
        const eventLower = (event || '').toLowerCase();
        if (eventLower.includes('login')) return <LogOut size={14} className="text-text-dim" />;
        if (eventLower.includes('password')) return <Key size={14} className="text-text-dim" />;
        if (eventLower.includes('analysis')) return <Shield size={14} className="text-text-dim" />;
        if (eventLower.includes('upload')) return <Upload size={14} className="text-text-dim" />;
        if (eventLower.includes('export')) return <Download size={14} className="text-text-dim" />;
        return <Activity size={14} className="text-text-dim" />;
    };

    const groupEventsByDate = (events) => {
        const groups = {};
        const today = new Date().toDateString();
        const yesterday = new Date(Date.now() - 86400000).toDateString();

        events.slice().reverse().forEach(event => {
            const eventDate = new Date(event.timestamp).toDateString();
            let label;

            if (eventDate === today) label = 'Today';
            else if (eventDate === yesterday) label = 'Yesterday';
            else label = new Date(event.timestamp).toLocaleDateString();

            if (!groups[label]) groups[label] = [];
            groups[label].push(event);
        });

        return groups;
    };

    if (!isOpen) return null;

    return (
        <>
            {/* Backdrop */}
            <div
                onClick={() => setIsOpen(false)}
                className="fixed inset-0 bg-black/60 z-[998] modal-backdrop"
            />

            {/* Panel */}
            <div
                className="fixed top-0 right-0 w-[400px] h-screen bg-surface border-l border-border z-[999]
                         flex flex-col fade-in"
                style={{
                    boxShadow: 'var(--shadow-lg)'
                }}
            >
                        {/* Header */}
                        <div className="flex items-center justify-between p-6 border-b border-border">
                            <h2 className="text-lg font-mono font-bold tracking-wider text-text uppercase">
                                Security
                            </h2>
                            <button
                                onClick={() => setIsOpen(false)}
                                className="w-8 h-8 flex items-center justify-center hover:bg-surface-hover
                                         transition-colors text-text-dim hover:text-text"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* Section Tabs */}
                        <div className="flex gap-2 p-3 border-b border-border">
                            <button
                                onClick={() => setActiveSection('account')}
                                className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-3 text-[11px]
                                         font-mono uppercase tracking-wider transition-all
                                         ${activeSection === 'account'
                                        ? 'bg-primary text-black font-bold'
                                        : 'bg-surface-hover text-text-dim hover:text-text'
                                    }`}
                            >
                                <User size={14} />
                                Account
                            </button>
                            <button
                                onClick={() => setActiveSection('activity')}
                                className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-3 text-[11px]
                                         font-mono uppercase tracking-wider transition-all
                                         ${activeSection === 'activity'
                                        ? 'bg-primary text-black font-bold'
                                        : 'bg-surface-hover text-text-dim hover:text-text'
                                    }`}
                            >
                                <Activity size={14} />
                                Activity
                            </button>
                            <button
                                onClick={() => setActiveSection('password')}
                                className={`flex-1 flex items-center justify-center gap-2 py-2.5 px-3 text-[11px]
                                         font-mono uppercase tracking-wider transition-all
                                         ${activeSection === 'password'
                                        ? 'bg-primary text-black font-bold'
                                        : 'bg-surface-hover text-text-dim hover:text-text'
                                    }`}
                            >
                                <Key size={14} />
                                Password
                            </button>
                        </div>

                        {/* Content */}
                        <div className="flex-1 overflow-y-auto p-6">
                            {/* Account Section */}
                            {activeSection === 'account' && userInfo && (
                                <div className="space-y-6">
                                    <div className="flex flex-col items-center text-center space-y-4">
                                        <div className="w-18 h-18 bg-primary/20 border-2 border-primary flex items-center
                                                      justify-center text-2xl font-bold text-primary">
                                            {(userInfo.username || 'U').charAt(0).toUpperCase()}
                                        </div>
                                        <div>
                                            <h3 className="text-lg font-mono font-bold text-text">
                                                {userInfo.username}
                                            </h3>
                                            <span className="inline-flex items-center gap-2 px-3 py-1 mt-2 text-[10px]
                                                           font-mono uppercase tracking-wider"
                                                style={{
                                                    background: userInfo.is_approved ? 'var(--color-success-bg)' : 'var(--color-warning-bg)',
                                                    color: userInfo.is_approved ? 'var(--color-success-text)' : 'var(--color-warning-text)',
                                                    border: `1px solid ${userInfo.is_approved ? 'var(--color-success-border)' : 'var(--color-warning-border)'}`
                                                }}
                                            >
                                                {userInfo.is_approved ? 'Approved' : 'Pending'}
                                            </span>
                                        </div>
                                    </div>

                                    <div className="space-y-3">
                                        <div className="flex justify-between py-3 border-b border-border">
                                            <span className="text-[11px] text-text-dim uppercase tracking-wider">Institution</span>
                                            <span className="text-[12px] font-mono text-text">{userInfo.institution || 'N/A'}</span>
                                        </div>
                                        <div className="flex justify-between py-3 border-b border-border">
                                            <span className="text-[11px] text-text-dim uppercase tracking-wider">Location</span>
                                            <span className="text-[12px] font-mono text-text">
                                                {userInfo.city && userInfo.country ? `${userInfo.city}, ${userInfo.country}` : 'N/A'}
                                            </span>
                                        </div>
                                        <div className="flex justify-between py-3 border-b border-border">
                                            <span className="text-[11px] text-text-dim uppercase tracking-wider">Role</span>
                                            <span className="text-[12px] font-mono text-text">{userInfo.role || 'User'}</span>
                                        </div>
                                    </div>

                                    <button
                                        onClick={handleSignOut}
                                        className="w-full flex items-center justify-center gap-3 py-3 px-4 border
                                                 text-[11px] font-mono uppercase tracking-wider transition-all
                                                 hover:bg-red-500/10"
                                        style={{
                                            borderColor: 'var(--color-error)',
                                            color: 'var(--color-error-text)'
                                        }}
                                    >
                                        <LogOut size={14} />
                                        Sign Out
                                    </button>
                                </div>
                            )}

                            {/* Activity Section */}
                            {activeSection === 'activity' && (
                                <div className="space-y-4">
                                    <div className="flex items-center justify-between">
                                        <h3 className="text-sm font-mono font-bold text-text uppercase tracking-wider">
                                            Activity Log
                                        </h3>
                                        <button
                                            onClick={exportActivityLog}
                                            className="flex items-center gap-2 px-3 py-1.5 bg-surface-hover border border-border
                                                     hover:border-primary/30 text-[10px] font-mono uppercase tracking-wider
                                                     text-text-dim hover:text-text transition-all"
                                        >
                                            <Download size={12} />
                                            Export
                                        </button>
                                    </div>

                                    {isLoadingActivity ? (
                                        <div className="flex flex-col items-center justify-center py-12 space-y-3">
                                            <div className="w-6 h-6 border-2 border-border border-t-primary rounded-full animate-spin" />
                                            <span className="text-[10px] text-text-dim">Loading...</span>
                                        </div>
                                    ) : activityLog.length === 0 ? (
                                        <p className="text-center py-12 text-[11px] text-text-dim">No activity recorded yet.</p>
                                    ) : (
                                        <div className="space-y-5">
                                            {Object.entries(groupEventsByDate(activityLog)).map(([date, events]) => (
                                                <div key={date}>
                                                    <div className="text-[10px] font-mono uppercase tracking-wider text-text-dim mb-2">
                                                        {date}
                                                    </div>
                                                    {events.map((event, i) => (
                                                        <div key={i} className="flex gap-3 py-2 border-b border-border/50">
                                                            <span className="flex-shrink-0">{getEventIcon(event.event)}</span>
                                                            <div className="flex-1">
                                                                <div className="text-[12px] text-text">{event.event}</div>
                                                                <div className="text-[10px] text-text-dim mt-0.5">
                                                                    {new Date(event.timestamp).toLocaleTimeString([], {
                                                                        hour: '2-digit',
                                                                        minute: '2-digit'
                                                                    })}
                                                                    {event.ip && event.ip !== 'local' && ` • ${event.ip}`}
                                                                </div>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Password Section */}
                            {activeSection === 'password' && (
                                <div className="space-y-4">
                                    <h3 className="text-sm font-mono font-bold text-text uppercase tracking-wider">
                                        Change Password
                                    </h3>

                                    {passwordSuccess && (
                                        <div className="p-3 text-[11px] font-mono"
                                            style={{
                                                background: 'var(--color-success-bg)',
                                                border: '1px solid var(--color-success-border)',
                                                color: 'var(--color-success-text)'
                                            }}>
                                            ✓ Password changed successfully
                                        </div>
                                    )}

                                    {passwordError && (
                                        <div className="p-3 text-[11px] font-mono"
                                            style={{
                                                background: 'var(--color-error-bg)',
                                                border: '1px solid var(--color-error-border)',
                                                color: 'var(--color-error-text)'
                                            }}>
                                            ⚠️ {passwordError}
                                        </div>
                                    )}

                                    <form onSubmit={handlePasswordChange} className="space-y-4">
                                        <div>
                                            <label className="block text-[11px] font-mono uppercase tracking-wider text-text-dim mb-2">
                                                Current Password
                                            </label>
                                            <input
                                                type="password"
                                                value={currentPassword}
                                                onChange={(e) => setCurrentPassword(e.target.value)}
                                                required
                                                className="w-full px-3 py-2.5 bg-surface-elevated border border-border
                                                         text-[12px] font-mono text-text
                                                         focus:border-primary/50 outline-none transition-all"
                                            />
                                        </div>

                                        <div>
                                            <label className="block text-[11px] font-mono uppercase tracking-wider text-text-dim mb-2">
                                                New Password
                                            </label>
                                            <input
                                                type="password"
                                                value={newPassword}
                                                onChange={(e) => setNewPassword(e.target.value)}
                                                required
                                                minLength={8}
                                                className="w-full px-3 py-2.5 bg-surface-elevated border border-border
                                                         text-[12px] font-mono text-text
                                                         focus:border-primary/50 outline-none transition-all"
                                            />
                                        </div>

                                        <div>
                                            <label className="block text-[11px] font-mono uppercase tracking-wider text-text-dim mb-2">
                                                Confirm New Password
                                            </label>
                                            <input
                                                type="password"
                                                value={confirmPassword}
                                                onChange={(e) => setConfirmPassword(e.target.value)}
                                                required
                                                className="w-full px-3 py-2.5 bg-surface-elevated border border-border
                                                         text-[12px] font-mono text-text
                                                         focus:border-primary/50 outline-none transition-all"
                                            />
                                        </div>

                                        <button
                                            type="submit"
                                            className="w-full py-3 px-4 bg-primary text-black font-mono font-bold
                                                     text-[11px] uppercase tracking-wider hover:bg-primary-hover
                                                     transition-all"
                                        >
                                            Update Password
                                        </button>
                                    </form>
                                </div>
                            )}
                        </div>
                    </div>
        </>
    );
};

export default SecurityPanel;
