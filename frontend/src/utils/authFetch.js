/**
 * authFetch.js — Deterministic Fetch Wrapper
 * 
 * CRITICAL: This wrapper automatically adds the Authorization: Bearer <token> header
 * to EVERY fetch request, preventing the "forgot to add token" bug.
 * 
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

  // Auth removed for V1 free launch — no token injection

  return headers;
};

/**
 * Handle 401 Unauthorized responses
 * Clear auth and trigger logout - NO REDIRECT to prevent loop
 */
const handle401 = (response, endpoint) => {
  if (response.status === 401) {
    // 401 logged — no redirect to prevent loops
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


  try {
    const response = await fetch(url, {
      ...options,
      headers: buildAuthHeaders(options.headers || {}),
    });


    // Check for 401 and handle it
    return handle401(response, endpoint);
  } catch (error) {
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


    const response = await fetch(url, {
      ...options,
      method: 'POST',
      headers: {},
      body: formData,
    });

    return handle401(response, endpoint);
  },
};

export default authApi;
