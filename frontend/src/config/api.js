export const API_BASE =
  import.meta.env.VITE_API_BASE?.trim() || 'http://localhost:8000';

export const apiUrl = (path) => `${API_BASE}${path.startsWith('/') ? '' : '/'}${path}`;

