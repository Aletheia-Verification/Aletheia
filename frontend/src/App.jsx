import React, { useState, useEffect } from 'react';
import LoginPage from './pages/LoginPage';
import TheSanctuary from './components/TheSanctuary';
import HomePage from './components/HomePage';
import TopNav from './components/TopNav';
import Vault from './components/Vault';
import Engine from './components/Engine';
import SecurityPanel from './components/SecurityPanel';
import EngineTransition from './components/EngineTransition';
import VaultTransition from './components/VaultTransition';
import { useAuth } from './context/AuthContext';

function App() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH CONTEXT: Single source of truth for authentication
  // ═══════════════════════════════════════════════════════════════════════════
  const auth = useAuth();

  // ═══════════════════════════════════════════════════════════════════════════
  // UI STATE: Only UI-specific state here, not auth-related
  // ═══════════════════════════════════════════════════════════════════════════
  const [currentView, setCurrentView] = useState('home');
  const [transitioning, setTransitioning] = useState(null);
  const [securityOpen, setSecurityOpen] = useState(false);
  const [isSanctuary, setIsSanctuary] = useState(false);

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION: Fetch profile when authenticated
  // DETERMINISTIC: Only runs AFTER isInitialized is true
  // ═══════════════════════════════════════════════════════════════════════════
  useEffect(() => {
    console.group('🔐 APP-INIT-CHECK');
    console.log('isInitialized:', auth.isInitialized);
    console.log('isAuthenticated:', auth.isAuthenticated);
    console.log('hasProfile:', !!auth.userProfile);
    console.groupEnd();

    // CRITICAL: Only proceed if initialized AND authenticated AND no profile yet
    if (auth.isInitialized && auth.isAuthenticated && !auth.userProfile) {
      auth.fetchProfile();
    }
  }, [auth.isInitialized, auth.isAuthenticated, auth.userProfile]);

  // Navigation handler with transition animation
  const handleNavigate = (view) => {
    setTransitioning(view);
    const duration = view === 'vault' ? 2400 : 3200;
    setTimeout(() => {
      setCurrentView(view);
      setTransitioning(null);
    }, duration);
  };

  const handleBackToHome = () => {
    setCurrentView('home');
  };

  const handleSecurityOpen = () => {
    setSecurityOpen(true);
  };


  // ═══════════════════════════════════════════════════════════════════════════
  // CONDITIONAL RENDERING: Gate users through auth checks
  // ═══════════════════════════════════════════════════════════════════════════

  // Gate 0: Auth not yet initialized - show loading state
  if (!auth.isInitialized) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary mb-4" />
          <p className="text-text-dim font-mono">Initializing secure session...</p>
        </div>
      </div>
    );
  }

  // Gate 1: Not Authenticated - show login or sanctuary
  if (!auth.isAuthenticated) {
    if (isSanctuary) {
      return (
        <TheSanctuary onEnter={() => setIsSanctuary(false)} />
      );
    }
    return (
      <LoginPage />
    );
  }

  // Gate 2: Bypassed — all authenticated users have dashboard access

  // Gate 3: Authenticated and approved - show main app
  // Transition Animations
  if (transitioning === 'engine') {
    return <EngineTransition />;
  }

  if (transitioning === 'vault') {
    return <VaultTransition />;
  }

  // Home Gateway
  if (currentView === 'home') {
    return <HomePage onNavigate={handleNavigate} />;
  }

  // Engine View
  if (currentView === 'engine') {
    return (
      <div className="min-h-screen bg-background">
        <TopNav
          onBack={handleBackToHome}
          onLogout={auth.logout}
          title="THE ENGINE"
          onSecurityClick={handleSecurityOpen}
        />
        <main className="pt-4">
          <Engine />
        </main>
        <SecurityPanel isOpen={securityOpen} setIsOpen={setSecurityOpen} />
      </div>
    );
  }

  // Vault View
  if (currentView === 'vault') {
    return (
      <div className="min-h-screen bg-background">
        <TopNav
          onBack={handleBackToHome}
          onLogout={auth.logout}
          title="THE VAULT"
          onSecurityClick={handleSecurityOpen}
        />
        <main className="pt-4">
          <Vault />
        </main>
        <SecurityPanel isOpen={securityOpen} setIsOpen={setSecurityOpen} />
      </div>
    );
  }

  return null;
}

export default App;
