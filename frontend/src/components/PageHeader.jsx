const PageHeader = ({ icon: Icon, title, subtitle }) => (
    <div className="mb-8 pb-6 border-b border-[#E5E7EB]">
        <div className="flex items-center gap-3">
            {Icon && <Icon size={20} strokeWidth={1.5} style={{ color: '#1B2A4A' }} />}
            <h1
                className="text-base font-medium tracking-[0.25em] uppercase"
                style={{ color: '#1A1A2E' }}
            >
                {title}
            </h1>
        </div>
        {subtitle && (
            <p
                className="text-[11px] tracking-[0.15em] uppercase mt-2"
                style={{ color: '#6B7280' }}
            >
                {subtitle}
            </p>
        )}
    </div>
);

export default PageHeader;
