import React from 'react';

const sizeMap = {
    sm: 'w-8 h-8',
    md: 'w-12 h-12',
    lg: 'w-[72px] h-[72px]',
};

const Logo = ({ className, size = 'md', theme = 'gold', onClick }) => {
    const accentColor = theme === 'silver' ? '#64748B' : '#D4AF37';
    const sizeClass = typeof size === 'number' ? `w-[${size}px] h-[${size}px]` : (sizeMap[size] || sizeMap.md);
    const finalClass = className || sizeClass;

    return (
        <svg
            viewBox="0 0 100 100"
            className={`${finalClass} ${onClick ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''}`}
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            onClick={onClick}
            style={{ color: accentColor }}
        >
            {/* Left stroke: Bold */}
            <path
                d="M50 10L10 90"
                stroke="currentColor"
                strokeWidth="14"
                strokeLinecap="square"
            />
            {/* Right stroke: Hairline */}
            <path
                d="M50 10L90 90"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="square"
            />
            {/* Cross bar: Sharp */}
            <path
                d="M28 62H72"
                stroke="currentColor"
                strokeWidth="3"
                strokeLinecap="square"
            />
        </svg>
    );
};

export default Logo;
