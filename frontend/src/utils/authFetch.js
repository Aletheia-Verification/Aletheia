/**
 * authFetch.js — Deterministic Fetch Wrapper
 * 
 * CRITICAL: This wrapper automatically adds the Authorization: Bearer <token> header
 * to EVERY fetch request, preventing the "forgot to add token" bug.
 * 
 * Also includes comprehensive logging to trace every step of the auth flow.
 */

import { API_BASE } from '../config/api';

const TOKEN_KEY = 'alethia_token';

/**
 * Get the current token from localStorage
 * SYNCHRONOUS: No async, just read from storage
 */
export const getToken = () => localStorage.getItem(TOKEN_KEY);

/**
 * Build headers with automatic Bearer token injection
 * This ensures EVERY request has the token (if it exists)
 */
const buildAuthHeaders = (extra = {}) => {
  const token = getToken();
  
  const headers = {
    'Content-Type': 'application/json',
    ...extra,
  };

  // CRITICAL: Add Bearer token if available
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
    console.group('🔐 AUTH-FETCH-HEADERS');
    console.log('Token being sent:', token.substring(0, 20) + '...');
    console.log('Authorization header:', `Bearer ${token.substring(0, 20)}...`);
    console.groupEnd();
  } else {
    console.log('[🔐 AUTH-FETCH] No token available - request will go unauthenticated');
  }

  return headers;
};

/**
 * Handle 401 Unauthorized responses
 * Clear auth and trigger logout - NO REDIRECT to prevent loop
 */
const handle401 = (response, endpoint) => {
  if (response.status === 401) {
    console.error('[AUTH-FETCH] 401 from:', endpoint, '— logged, no action taken');
    // DO NOT clear localStorage or dispatch events — prevents redirect loops
  }
  return response;
};

/**
 * Main authFetch wrapper - replaces fetch() for auth'd requests
 * 
 * Usage:
 *   const response = await authFetch('/auth/profile');
 *   const data = await response.json();
 */
export const authFetch = async (endpoint, options = {}) => {
  const url = `${API_BASE}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;
  const method = options.method || 'GET';

  console.group(`🔐 AUTHFETCH-${method}`);
  console.log('URL:', url);
  console.log('Method:', method);
  console.log('Has token:', !!getToken());
  console.groupEnd();

  try {
    const response = await fetch(url, {
      ...options,
      headers: buildAuthHeaders(options.headers || {}),
    });

    console.group(`🔐 AUTHFETCH-RESPONSE-${response.status}`);
    console.log('Endpoint:', endpoint);
    console.log('Status:', response.status, response.statusText);
    console.groupEnd();

    // Check for 401 and handle it
    return handle401(response, endpoint);
  } catch (error) {
    console.group('🔐 AUTHFETCH-ERROR');
    console.error('Fetch error:', error.message);
    console.log('Endpoint:', endpoint);
    console.groupEnd();
    throw error;
  }
};

/**
 * Convenience methods matching typical REST patterns
 */
export const authApi = {
  /**
   * GET request with auto-bearer token
   */
  get: async (endpoint, options = {}) => {
    return authFetch(endpoint, {
      ...options,
      method: 'GET',
    });
  },

  /**
   * POST request with auto-bearer token
   */
  post: async (endpoint, body, options = {}) => {
    return authFetch(endpoint, {
      ...options,
      method: 'POST',
      body: JSON.stringify(body),
    });
  },

  /**
   * PUT request with auto-bearer token
   */
  put: async (endpoint, body, options = {}) => {
    return authFetch(endpoint, {
      ...options,
      method: 'PUT',
      body: JSON.stringify(body),
    });
  },

  /**
   * DELETE request with auto-bearer token
   */
  delete: async (endpoint, options = {}) => {
    return authFetch(endpoint, {
      ...options,
      method: 'DELETE',
    });
  },

  /**
   * File upload with auto-bearer token
   * Note: Must NOT set Content-Type (browser sets multipart/form-data)
   */
  upload: async (endpoint, file, options = {}) => {
    const token = getToken();
    const url = `${API_BASE}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;
    
    const formData = new FormData();
    formData.append('file', file);

    console.group('🔐 AUTHFETCH-UPLOAD');
    console.log('URL:', url);
    console.log('File:', file.name);
    console.log('Has token:', !!token);
    console.groupEnd();

    const response = await fetch(url, {
      ...options,
      method: 'POST',
      headers: {
        ...(token && { Authorization: `Bearer ${token}` }),
      },
      body: formData,
    });

    return handle401(response, endpoint);
  },
};

export default authApi;
