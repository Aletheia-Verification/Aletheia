const STATUS_STYLES = {
    green: {
        bg: '#F0FDF4',
        text: '#16A34A',
        border: '#16A34A',
        label: 'VERIFIED',
    },
    yellow: {
        bg: '#FFFBEB',
        text: '#D97706',
        border: '#D97706',
        label: 'ATTENTION',
    },
    red: {
        bg: '#FEF2F2',
        text: '#DC2626',
        border: '#DC2626',
        label: 'MANUAL REVIEW',
    },
};

const StatusBadge = ({ status, label }) => {
    const s = STATUS_STYLES[status] || STATUS_STYLES.green;
    return (
        <span
            className="inline-block px-3 py-1 text-[10px] tracking-[0.1em] uppercase font-semibold"
            style={{
                backgroundColor: s.bg,
                color: s.text,
                border: `1px solid ${s.border}`,
            }}
        >
            {label || s.label}
        </span>
    );
};

export default StatusBadge;
