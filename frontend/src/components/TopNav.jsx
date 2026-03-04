import React from 'react';
import { ArrowLeft, LogOut, Shield } from 'lucide-react';

import Logo from './Logo';

const TopNav = ({ onBack, onLogout, title, onSecurityClick }) => {

  return (
    <header className="sticky top-0 z-40 bg-white/90 backdrop-blur-sm border-b border-[#E5E7EB]">
      <div className="flex items-center justify-between px-6 py-3.5">
        {/* Left: Back + Title */}
        <div className="flex items-center gap-5">
          <button
            onClick={onBack}
            className="flex items-center gap-2 text-[#6B7280] hover:text-[#1B2A4A] transition-colors duration-200 group"
          >
            <ArrowLeft size={16} className="group-hover:-translate-x-0.5 transition-transform duration-200" />
            <span className="text-[11px] tracking-[0.15em] uppercase">Home</span>
          </button>

          <div className="h-4 w-px bg-[#E5E7EB]" />

          <div className="flex items-center gap-3">
            <Logo size={20} theme="gold" />
            <h1 className="text-[13px] tracking-[0.2em] uppercase text-[#1A1A2E] font-medium">
              {title}
            </h1>
          </div>
        </div>

        {/* Right: Theme + Security + Logout */}
        <div className="flex items-center gap-5">
          {/* Security */}
          <button
            onClick={onSecurityClick}
            className="flex items-center gap-2 text-[#6B7280] hover:text-[#1B2A4A] transition-colors duration-200"
            title="Security & Settings"
          >
            <Shield size={16} strokeWidth={1.5} />
            <span className="text-[11px] tracking-wider uppercase hidden md:block">Security</span>
          </button>

          <div className="h-4 w-px bg-[#E5E7EB]" />

          {/* Logout */}
          <button
            onClick={onLogout}
            className="flex items-center gap-2 text-[#6B7280] hover:text-[#DC2626] transition-colors duration-200"
          >
            <LogOut size={16} strokeWidth={1.5} />
            <span className="text-[11px] tracking-wider uppercase hidden md:block">Sign Out</span>
          </button>
        </div>
      </div>
    </header>
  );
};

export default TopNav;
