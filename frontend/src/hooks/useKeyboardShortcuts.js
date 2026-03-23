import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const NAV_ROUTES = [
    '/dashboard',       // Ctrl+1
    '/analyze',         // Ctrl+2
    '/verify',          // Ctrl+3
    '/trace',           // Ctrl+4
    '/portfolio',       // Ctrl+5
    '/compiler-matrix', // Ctrl+6
    '/dead-code',       // Ctrl+7
    '/sbom',            // Ctrl+8
    '/jcl',             // Ctrl+9
];

/**
 * Global keyboard shortcuts for power users.
 *
 * @param {Object} opts
 * @param {Function} [opts.onSubmit]    — Ctrl+Enter handler (e.g., run analysis)
 * @param {Function} [opts.onExportPdf] — Ctrl+E handler (e.g., export PDF)
 * @param {Function} [opts.onEscape]    — Escape handler (e.g., close sidebar)
 */
export function useKeyboardShortcuts({ onSubmit, onExportPdf, onEscape } = {}) {
    const navigate = useNavigate();

    useEffect(() => {
        function handleKeyDown(e) {
            const tag = e.target.tagName;

            // Don't intercept when typing in input/textarea/select
            if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') {
                if (e.key === 'Escape') {
                    e.target.blur();
                }
                return;
            }

            // Ctrl+1-9: Navigate to sidebar pages
            if (e.ctrlKey && !e.shiftKey && !e.altKey) {
                const num = parseInt(e.key);
                if (num >= 1 && num <= 9 && NAV_ROUTES[num - 1]) {
                    e.preventDefault();
                    navigate(NAV_ROUTES[num - 1]);
                    return;
                }
            }

            // Ctrl+Enter: Submit/Analyze
            if (e.ctrlKey && e.key === 'Enter' && onSubmit) {
                e.preventDefault();
                onSubmit();
                return;
            }

            // Ctrl+E: Export PDF (Executive)
            if (e.ctrlKey && e.key === 'e' && !e.shiftKey && onExportPdf) {
                e.preventDefault();
                onExportPdf();
                return;
            }

            // Escape: Close panels/sidebar
            if (e.key === 'Escape' && onEscape) {
                onEscape();
            }
        }

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [navigate, onSubmit, onExportPdf, onEscape]);
}
