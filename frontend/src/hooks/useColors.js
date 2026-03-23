/**
 * useColors — centralized theme-aware color constants.
 *
 * Replaces per-component `const C = {...}` with `const C = useColors()`.
 * Returns LIGHT or DARK palette based on ThemeContext isDark state.
 */

import { useTheme } from '../context/ThemeContext';

const LIGHT = {
    navy: '#1B2A4A',
    navyLight: '#2D3F5E',
    text: '#1A1A2E',
    body: '#2D2D3D',
    muted: '#5A5A6E',
    faint: '#6B7280',
    border: '#E5E7EB',
    borderLight: '#F0F0F0',
    bg: '#FFFFFF',
    bgAlt: '#F8F9FA',
    green: '#16A34A',
    greenBg: '#F0FDF4',
    greenBorder: '#BBF7D0',
    amber: '#D97706',
    amberBg: '#FFFBEB',
    amberBorder: '#FDE68A',
    red: '#DC2626',
    redBg: '#FEF2F2',
    redBorder: '#FECACA',
    gold: '#C9A84C',
};

const DARK = {
    navy: '#93B5E8',
    navyLight: '#7CA0D6',
    text: '#E5E7EB',
    body: '#D1D5DB',
    muted: '#9CA3AF',
    faint: '#6B7280',
    border: 'rgba(255,255,255,0.1)',
    borderLight: 'rgba(255,255,255,0.06)',
    bg: '#0A0F1A',
    bgAlt: '#111827',
    green: '#4ADE80',
    greenBg: 'rgba(74,222,128,0.1)',
    greenBorder: 'rgba(74,222,128,0.2)',
    amber: '#FBBF24',
    amberBg: 'rgba(251,191,36,0.1)',
    amberBorder: 'rgba(251,191,36,0.2)',
    red: '#F87171',
    redBg: 'rgba(248,113,113,0.1)',
    redBorder: 'rgba(248,113,113,0.2)',
    gold: '#C9A84C',
};

export function useColors() {
    return LIGHT;
}

export { LIGHT, DARK };
