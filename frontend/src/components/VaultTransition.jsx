import React from 'react';
import { motion } from 'framer-motion';
import { Lock } from 'lucide-react';

const VaultTransition = () => {
  // Heavy hydraulic easing - slow start, controlled acceleration
  const heavyEase = [0.7, 0, 0.3, 1];

  return (
    <div className="fixed inset-0 bg-background z-50 overflow-hidden">
      {/* Center seam line - splits first */}
      <motion.div
        initial={{ scaleY: 1, opacity: 1 }}
        animate={{ scaleY: 0, opacity: 0 }}
        transition={{
          duration: 0.3,
          delay: 0.4,
          ease: [0.4, 0, 0.2, 1],
        }}
        className="absolute left-1/2 top-0 bottom-0 w-px bg-primary/30 origin-center z-20"
      />

      {/* Left Door */}
      <motion.div
        initial={{ x: 0 }}
        animate={{ x: '-100%' }}
        transition={{
          duration: 1.8,
          delay: 0.5,
          ease: heavyEase,
        }}
        className="absolute top-0 left-0 w-1/2 h-full bg-surface border-r-2 border-primary/20"
      >
        {/* Door thickness edge (3D suggestion) */}
        <div className="absolute top-0 right-0 w-3 h-full bg-gradient-to-l from-black/10 to-transparent" />

        {/* Horizontal reinforcement bars */}
        <div className="absolute inset-0 flex flex-col justify-center items-end pr-12">
          <div className="space-y-6 w-40">
            {[...Array(7)].map((_, i) => (
              <div key={i} className="h-0.5 bg-border/60" />
            ))}
          </div>
        </div>

        {/* Corner bolts */}
        <div className="absolute top-6 left-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute top-6 right-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute bottom-6 left-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute bottom-6 right-6 w-3 h-3 rounded-full border-2 border-border/40" />

        {/* Door number plate */}
        <div className="absolute top-12 left-12 px-3 py-1 border border-border/30">
          <span className="font-mono text-[10px] tracking-widest text-text-dim/50 uppercase">L-01</span>
        </div>
      </motion.div>

      {/* Right Door */}
      <motion.div
        initial={{ x: 0 }}
        animate={{ x: '100%' }}
        transition={{
          duration: 1.8,
          delay: 0.5,
          ease: heavyEase,
        }}
        className="absolute top-0 right-0 w-1/2 h-full bg-surface border-l-2 border-primary/20"
      >
        {/* Door thickness edge (3D suggestion) */}
        <div className="absolute top-0 left-0 w-3 h-full bg-gradient-to-r from-black/10 to-transparent" />

        {/* Horizontal reinforcement bars */}
        <div className="absolute inset-0 flex flex-col justify-center items-start pl-12">
          <div className="space-y-6 w-40">
            {[...Array(7)].map((_, i) => (
              <div key={i} className="h-0.5 bg-border/60" />
            ))}
          </div>
        </div>

        {/* Corner bolts */}
        <div className="absolute top-6 left-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute top-6 right-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute bottom-6 left-6 w-3 h-3 rounded-full border-2 border-border/40" />
        <div className="absolute bottom-6 right-6 w-3 h-3 rounded-full border-2 border-border/40" />

        {/* Door number plate */}
        <div className="absolute top-12 right-12 px-3 py-1 border border-border/30">
          <span className="font-mono text-[10px] tracking-widest text-text-dim/50 uppercase">R-01</span>
        </div>
      </motion.div>

      {/* Center Lock Mechanism */}
      <motion.div
        initial={{ rotate: 0, scale: 1 }}
        animate={{ rotate: -90, scale: 0.9 }}
        transition={{
          duration: 0.4,
          delay: 0,
          ease: [0.4, 0, 0.2, 1],
        }}
        className="absolute inset-0 flex items-center justify-center z-30"
      >
        <motion.div
          initial={{ opacity: 1 }}
          animate={{ opacity: 0 }}
          transition={{ duration: 0.3, delay: 0.4 }}
          className="w-24 h-24 rounded-full border-2 border-primary/60 flex items-center justify-center bg-background shadow-[0_0_40px_rgba(0,0,0,0.3)]"
        >
          <Lock size={40} className="text-primary" />
        </motion.div>
      </motion.div>

      {/* Title - fades in after doors start moving */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5, delay: 1.2 }}
        className="absolute inset-x-0 bottom-[28%] flex justify-center z-40"
      >
        <h2 className="font-mono text-sm tracking-[0.5em] uppercase text-text-dim">
          Vault Open
        </h2>
      </motion.div>
    </div>
  );
};

export default VaultTransition;
