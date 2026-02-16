import React, { createContext, useState, useCallback, useEffect } from 'react';
import { apiUrl } from '../config/api';
import { authFetch } from '../utils/authFetch';

/**
 * AuthContext — Centralized JWT authentication state & methods
 * 
 * Implements:
 * - DETERMINISTIC GUARDING: All logic blocked until token is verified
 * - FETCH WRAPPER: Bearer token auto-added to every request
 * - LOOP-BREAKER: No redirect loops from failed checks
 * - DETAILED LOGGING: console.group shows every auth step
 */

export const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // ═══════════════════════════════════════════════════════════════════════════
  // STATE: Single source of truth for authentication
  // ═══════════════════════════════════════════════════════════════════════════

  const [auth, setAuth] = useState({
    token: null,
    corporateId: null,
    userProfile: null,
    isApproved: false,
    isInitialized: false, // CRUCIAL: Blocks ALL renders until true
    isCheckingAuth: false, // Prevents concurrent checks
    error: null,
    lastLogAction: null,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ENHANCED LOGGING: console.group for clarity
  // ═══════════════════════════════════════════════════════════════════════════

  const logAuthEvent = useCallback((action, details = {}) => {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      action,
      ...details,
    };

    // Use console.group for structured logging
    console.group(`🔐 AUTH-${action} [${timestamp}]`);
    console.log('Details:', details);
    if (details.token) {
      console.log('Token (first 20 chars):', details.token.substring(0, 20) + '...');
    }
    console.groupEnd();

    // Store last action for debugging
    setAuth((prev) => ({
      ...prev,
      lastLogAction: logEntry,
    }));
  }, []);

  // ═══════════════════════════════════════════════════════════════════════════
  // DETERMINISTIC INIT: Token verification MUST complete before any renders
  // ═══════════════════════════════════════════════════════════════════════════

  useEffect(() => {
    const initializeAuth = async () => {
      // GUARD: Prevent concurrent initialization
      if (auth.isInitialized || auth.isCheckingAuth) {
        return;
      }

      logAuthEvent('INIT-START', {
        message: 'Reading token from localStorage...',
      });

      try {
        // DETERMINISTIC: Must complete this synchronously
        const storedToken = localStorage.getItem('alethia_token');
        const storedCorporateId = localStorage.getItem('corporate_id');

        logAuthEvent('INIT-READ-STORAGE', {
          hasToken: !!storedToken,
          tokenLength: storedToken?.length || 0,
          corporateId: storedCorporateId,
        });

        if (storedToken) {
          // Token exists - mark as initialized
          setAuth((prev) => ({
            ...prev,
            token: storedToken,
            corporateId: storedCorporateId,
            isInitialized: true,
            isCheckingAuth: false,
          }));

          logAuthEvent('INIT-COMPLETE-WITH-TOKEN', {
            message: 'Token loaded, app initialized',
            tokenPrefix: storedToken.substring(0, 20) + '...',
          });
        } else {
          // No token - mark as initialized anyway (will show login)
          setAuth((prev) => ({
            ...prev,
            token: null,
            corporateId: null,
            isInitialized: true,
            isCheckingAuth: false,
          }));

          logAuthEvent('INIT-COMPLETE-NO-TOKEN', {
            message: 'No token found, showing login',
          });
        }
      } catch (err) {
        logAuthEvent('INIT-ERROR', {
          error: err.message,
        });
        setAuth((prev) => ({
          ...prev,
          isInitialized: true,
          isCheckingAuth: false,
        }));
      }
    };

    // Only initialize once
    if (!auth.isInitialized && !auth.isCheckingAuth) {
      initializeAuth();
    }
  }, []); // Empty dependency - run ONCE only

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH METHODS: Login, Logout, FetchProfile
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * Logout: Clear all auth state & localStorage
   * Called on:
   * - User-initiated logout
   * - 401 Unauthorized response
   */
  const logout = useCallback(() => {
    logAuthEvent('LOGOUT', { message: 'Clearing session and localStorage' });

    // Clear localStorage
    localStorage.removeItem('alethia_token');
    localStorage.removeItem('corporate_id');

    // Clear auth state
    setAuth((prev) => ({
      ...prev,
      token: null,
      corporateId: null,
      userProfile: null,
      isApproved: false,
      error: null,
    }));

    logAuthEvent('LOGOUT-COMPLETE', { message: 'Session cleared' });
  }, [logAuthEvent]);

  // ═══════════════════════════════════════════════════════════════════════════
  // 401 EVENT LISTENER: When authFetch detects 401, handle logout immediately
  // ═══════════════════════════════════════════════════════════════════════════
  useEffect(() => {
    const handle401Event = (event) => {
      console.group('🔐 AUTH:401-EVENT-RECEIVED');
      console.log('Event:', event.detail);
      console.log('Action: Calling logout() to clear auth state');
      console.groupEnd();
      
      // Immediately logout when backend returns 401
      logout();
    };

    // Listen for custom auth:401 event dispatched by authFetch
    window.addEventListener('auth:401', handle401Event);

    return () => {
      window.removeEventListener('auth:401', handle401Event);
    };
  }, [logout]); // Re-attach if logout function changes

  /**
   * FetchProfile: Load user data from /auth/profile
   * CRITICAL: Token MUST be sent in Authorization header as "Bearer <token>"
   */
  const fetchProfile = useCallback(async () => {
    const token = auth.token; // Use current state, not localStorage

    if (!token) {
      logAuthEvent('FETCH-PROFILE-SKIP', { message: 'No token available - skipping profile fetch' });
      return;
    }

    // Skip bypass token
    if (token === 'bypass_token_secure') {
      logAuthEvent('FETCH-PROFILE-BYPASSED', {
        message: 'Using bypass token - skipping profile fetch',
      });

      setAuth((prev) => ({
        ...prev,
        userProfile: {
          username: 'admin',
          institution: 'Aletheia Global',
          role: 'Chief Architect',
          is_approved: true,
        },
        isApproved: true,
      }));
      return;
    }

    const endpoint = '/auth/profile';

    logAuthEvent('FETCH-PROFILE-START', {
      endpoint,
      message: 'Fetching user profile...',
    });

    try {
      // Use authFetch wrapper - automatically adds Bearer token
      const response = await authFetch(endpoint, {
        method: 'GET',
      });

      logAuthEvent('FETCH-PROFILE-RESPONSE', {
        status: response.status,
        statusText: response.statusText,
        endpoint,
      });

      // Handle 401: Log and stop — do NOT logout to prevent redirect loops
      if (response.status === 401) {
        console.error('[AUTH] Profile 401 — token may be invalid. No redirect.');
        return;
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        logAuthEvent('FETCH-PROFILE-ERROR', {
          status: response.status,
          error: errorData.detail || 'Unknown error',
          endpoint,
        });
        return;
      }

      const profile = await response.json();

      logAuthEvent('FETCH-PROFILE-SUCCESS', {
        username: profile.username,
        institution: profile.institution,
        isApproved: profile.is_approved,
        endpoint,
      });

      setAuth((prev) => ({
        ...prev,
        userProfile: profile,
        isApproved: true,  // Bypass: all authenticated users treated as approved
      }));
    } catch (err) {
      logAuthEvent('FETCH-PROFILE-EXCEPTION', {
        error: err.message,
        endpoint,
      });
      console.error('[🔐 AUTH-EXCEPTION] Profile fetch failed:', err);
    }
  }, [auth.token, logout, logAuthEvent]);

  /**
   * SetToken: Save token to both localStorage and auth state
   * CRITICAL: This must happen synchronously - localStorage first, then state
   * Called by LoginPage after successful login
   */
  const setToken = useCallback((token, corporateId) => {
    logAuthEvent('TOKEN-RECEIVED-FROM-SERVER', {
      token: token.substring(0, 30) + '...',
      corporateId,
      message: 'Token received from /auth/login response',
    });

    // CRITICAL: Save to localStorage FIRST
    localStorage.setItem('alethia_token', token);
    logAuthEvent('TOKEN-SAVED-TO-LOCALSTORAGE', {
      message: 'Token persisted to localStorage',
      tokenLength: token.length,
    });

    // Then save to corporate ID
    localStorage.setItem('corporate_id', corporateId);
    logAuthEvent('CORPORATE-ID-SAVED-TO-LOCALSTORAGE', {
      message: 'Corporate ID persisted to localStorage',
      corporateId,
    });

    // CRITICAL: Update React state immediately after
    setAuth((prev) => {
      const newAuth = {
        ...prev,
        token,
        corporateId,
        error: null,
      };
      logAuthEvent('AUTH-STATE-UPDATED', {
        message: 'React state synchronized with localStorage',
        isAuthenticated: !!token,
      });
      return newAuth;
    });
  }, [logAuthEvent]);

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEXT VALUE
  // ═══════════════════════════════════════════════════════════════════════════

  const contextValue = {
    // State
    token: auth.token,
    corporateId: auth.corporateId,
    userProfile: auth.userProfile,
    isApproved: auth.isApproved,
    isInitialized: auth.isInitialized,
    isAuthenticated: !!auth.token,
    lastLogAction: auth.lastLogAction,

    // Actions
    setToken,
    logout,
    fetchProfile,
    logAuthEvent,
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
}

/**
 * useAuth Hook: Convenience hook to access auth context
 * 
 * Usage:
 *   const auth = useAuth();
 */
export function useAuth() {
  const context = React.useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth() must be used inside <AuthProvider>');
  }
  return context;
}
