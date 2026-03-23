import React from 'react';
import { Cpu, Lock } from 'lucide-react';
import Logo from './Logo';

const HomePage = ({ onNavigate }) => {
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-6 md:px-10 py-16">
      {/* Wordmark */}
      <div className="mb-6 flex flex-col items-center fade-in">
        <Logo size={72} />
      </div>

      <div className="mb-16 text-center fade-in" style={{ animationDelay: '80ms' }}>
        <h1 className="text-2xl tracking-[0.4em] uppercase font-light text-[#1B2A4A] mb-2">
          Aletheia
        </h1>
        <p className="text-[11px] tracking-[0.2em] uppercase text-[#6B7280]">
          Deterministic behavioral verification for mainframe migrations
        </p>
        <p className="text-[10px] tracking-[0.15em] text-[#6B7280]/60 mt-2">
          Prove behavioral equivalence. No AI in the pipeline.
        </p>
      </div>

      {/* Gateway Cards */}
      <div className="flex flex-col md:flex-row gap-8 md:gap-10 w-full max-w-6xl">
        {/* The Engine Card — Primary */}
        <button
          onClick={() => onNavigate('engine')}
          className="flex-1 group relative bg-white border border-[#E5E7EB]
                     transition-all duration-200 p-12 md:p-14 lg:p-16
                     hover:shadow-md
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#1B2A4A]/20
                     fade-in"
          style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.06)', borderLeft: '3px solid #1B2A4A', animationDelay: '120ms' }}
        >
          <div className="flex flex-col items-center text-center">
            <div className="w-14 h-14 flex items-center justify-center mb-8
                          border border-[#E5E7EB]
                          transition-colors duration-200">
              <Cpu
                size={26}
                strokeWidth={1.5}
                className="text-[#6B7280] group-hover:text-[#1B2A4A] transition-colors duration-200"
              />
            </div>

            <h2 className="text-base md:text-lg tracking-[0.3em] uppercase text-[#1A1A2E] mb-3 font-medium">
              The Engine
            </h2>

            <p className="text-[11px] tracking-[0.2em] text-[#6B7280] uppercase">
              Upload COBOL &rarr; get verified
            </p>
          </div>
        </button>

        {/* The Vault Card */}
        <button
          onClick={() => onNavigate('vault')}
          className="flex-1 group relative bg-white border border-[#E5E7EB]
                     transition-all duration-200 p-12 md:p-14 lg:p-16
                     hover:shadow-md
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#1B2A4A]/20
                     fade-in"
          style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.06)', animationDelay: '180ms' }}
        >
          <div className="flex flex-col items-center text-center">
            <div className="w-14 h-14 flex items-center justify-center mb-8
                          border border-[#E5E7EB]
                          transition-colors duration-200">
              <Lock
                size={26}
                strokeWidth={1.5}
                className="text-[#6B7280] group-hover:text-[#1B2A4A] transition-colors duration-200"
              />
            </div>

            <h2 className="text-base md:text-lg tracking-[0.3em] uppercase text-[#1A1A2E] mb-3 font-medium">
              The Vault
            </h2>

            <p className="text-[11px] tracking-[0.2em] text-[#6B7280] uppercase">
              Audit trail of every verification
            </p>
          </div>
        </button>

      </div>

      {/* Footer */}
      <div className="mt-16 text-center fade-in" style={{ animationDelay: '300ms' }}>
        <p className="text-[11px] tracking-[0.25em] text-[#1B2A4A]/40 uppercase">
          Zero drift. Zero guesswork. Deterministic proof.
        </p>
      </div>
    </div>
  );
};

export default HomePage;
