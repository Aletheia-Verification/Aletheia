import React from 'react';
import { GitCompareArrows } from 'lucide-react';

const DiffTransition = () => {
  return (
    <div className="fixed inset-0 bg-white z-50 overflow-hidden flex items-center justify-center">
      {/* Scan line animation */}
      <style>{`
        @keyframes diff-scan {
          0% { transform: translateY(-100%); opacity: 0; }
          10% { opacity: 1; }
          90% { opacity: 1; }
          100% { transform: translateY(100vh); opacity: 0; }
        }
        @keyframes diff-fade-in {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes diff-line-sweep {
          from { transform: scaleX(0); }
          to { transform: scaleX(1); }
        }
        .diff-scan-line {
          animation: diff-scan 2s ease-in-out forwards;
        }
        .diff-content {
          animation: diff-fade-in 0.6s ease-out 0.4s both;
        }
        .diff-line {
          animation: diff-line-sweep 0.8s ease-out 0.8s both;
          transform-origin: center;
        }
        .diff-status {
          animation: diff-fade-in 0.5s ease-out 1.2s both;
        }
      `}</style>

      {/* Horizontal scan line */}
      <div className="absolute left-0 right-0 h-px bg-[#1B2A4A]/30 diff-scan-line" />

      {/* Center content */}
      <div className="relative flex flex-col items-center gap-8">
        {/* Icon */}
        <div className="diff-content">
          <div className="w-20 h-20 border border-[#E5E7EB] flex items-center justify-center">
            <GitCompareArrows size={32} strokeWidth={1.5} className="text-[#1B2A4A]" />
          </div>
        </div>

        {/* Divider */}
        <div className="w-48 h-px bg-[#1B2A4A]/20 diff-line" />

        {/* Title */}
        <div className="diff-content flex flex-col items-center gap-3">
          <h2 className="font-mono text-sm tracking-[0.5em] uppercase text-[#1B2A4A] font-medium">
            Shadow Diff
          </h2>
        </div>

        {/* Status */}
        <p className="diff-status font-mono text-[10px] tracking-[0.3em] uppercase text-[#6B7280]">
          Initializing Replay
        </p>
      </div>

    </div>
  );
};

export default DiffTransition;
