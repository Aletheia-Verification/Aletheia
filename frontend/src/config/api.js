export const API_BASE =
  import.meta.env.VITE_API_BASE?.trim() || '';

export const apiUrl = (path) => `${API_BASE}${path.startsWith('/') ? '' : '/'}${path}`;

