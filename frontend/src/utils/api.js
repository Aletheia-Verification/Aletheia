/**
 * api.js — Centralized API helper with auto-authentication
 *
 * All requests automatically include the JWT token from localStorage.
 * 401 responses clear the token and redirect to login.
 * 
 * Every request is logged for debugging auth issues.
 */

import { API_BASE } from '../config/api';

const TOKEN_KEY = 'alethia_token';

export const getToken = () => localStorage.getItem(TOKEN_KEY);

const buildHeaders = (extra = {}) => {
  const token = getToken();
  return {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
    ...extra,
  };
};

/**
 * Handle 401 Unauthorized responses
 * 
 * Logs the error and cleans up auth state
 * Does NOT redirect - let the App.jsx render LoginPage via state
 */
const handle401 = (response, endpoint) => {
  if (response.status === 401) {
    console.log(`[🔐 API-401] Unauthorized response from ${endpoint}`);
    console.log('[🔐 API-401] Clearing authentication tokens...');
    
    // Clear localStorage
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem('corporate_id');
    
    // Dispatch custom event so AuthContext can listen and update state
    window.dispatchEvent(new CustomEvent('auth:logout', { 
      detail: { reason: '401_unauthorized', endpoint } 
    }));
    
    console.log('[🔐 API-401] Auth cleared - will redirect to login');
    
    // Short delay to let React update, then redirect
    setTimeout(() => {
      window.location.href = '/';
    }, 100);
  }
  return response;
};

// Request logging helper
const logRequest = (method, endpoint, options = {}) => {
  const token = getToken();
  console.log(`[🔐 API-REQUEST] ${method} ${endpoint}`, {
    hasToken: !!token,
    tokenPrefix: token ? `${token.substring(0, 20)}...` : 'none',
    ...options,
  });
};

// Response logging helper
const logResponse = (method, endpoint, status, data = {}) => {
  console.log(`[🔐 API-RESPONSE] ${method} ${endpoint} → ${status}`, data);
};

export const api = {
  get: async (endpoint) => {
    logRequest('GET', endpoint);
    
    const response = await fetch(`${API_BASE}${endpoint}`, {
      method: 'GET',
      headers: buildHeaders(),
    });
    
    logResponse('GET', endpoint, response.status);
    return handle401(response, endpoint);
  },

  post: async (endpoint, body) => {
    logRequest('POST', endpoint, { bodyKeys: Object.keys(body || {}) });
    
    const response = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: buildHeaders(),
      body: JSON.stringify(body),
    });
    
    logResponse('POST', endpoint, response.status);
    return handle401(response, endpoint);
  },

  upload: async (endpoint, file) => {
    const token = getToken();
    logRequest('POST (upload)', endpoint, { filename: file?.name });
    
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: {
        ...(token && { Authorization: `Bearer ${token}` }),
      },
      body: formData,
    });
    
    logResponse('POST (upload)', endpoint, response.status);
    return handle401(response, endpoint);
  },
};

export default api;
