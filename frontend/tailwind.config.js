/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                background: 'var(--background)',
                surface: 'var(--surface)',
                'surface-highlight': 'var(--surface-highlight)',
                border: 'var(--border)',
                primary: 'var(--primary)',
                'primary-glow': 'var(--primary-glow)',
                text: 'var(--text)',
                'text-dim': 'var(--text-dim)',
            },
            fontFamily: {
                sans: ['Inter', 'sans-serif'],
                mono: ['"JetBrains Mono"', 'monospace'],
            },
            animation: {
                'fade-in': 'fadeIn 0.5s ease-out',
                'slide-up': 'slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1)',
                'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                'pulse-gold': 'pulseGold 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                'glow-gold': 'glowGold 3s ease-in-out infinite',
            },
            keyframes: {
                fadeIn: {
                    '0%': { opacity: '0' },
                    '100%': { opacity: '1' },
                },
                slideUp: {
                    '0%': { transform: 'translateY(20px)', opacity: '0' },
                    '100%': { transform: 'translateY(0)', opacity: '1' },
                },
                pulseGold: {
                    '0%, 100%': { borderColor: 'rgba(234, 179, 8, 0.3)', boxShadow: '0 0 5px rgba(234, 179, 8, 0.1)' },
                    '50%': { borderColor: 'rgba(234, 179, 8, 0.7)', boxShadow: '0 0 15px rgba(234, 179, 8, 0.3)' },
                },
                glowGold: {
                    '0%, 100%': { opacity: '0.5' },
                    '50%': { opacity: '1', textShadow: '0 0 10px rgba(234, 179, 8, 0.5)' },
                }
            }
        },
    },
    plugins: [],
}
