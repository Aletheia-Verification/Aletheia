import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/engine': 'http://localhost:8000',
      '/auth': 'http://localhost:8000',
      '/vault': 'http://localhost:8000',
      '/shadow-diff': 'http://localhost:8000',
      '/chat': 'http://localhost:8000',
      '/copybook': 'http://localhost:8000',
      '/license': 'http://localhost:8000',
      '/dependency': 'http://localhost:8000',
      '/analytics': 'http://localhost:8000',
      '/demo-data': 'http://localhost:8000',
    },
  },
})
