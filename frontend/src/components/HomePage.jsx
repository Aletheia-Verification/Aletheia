import React from 'react';
import { motion } from 'framer-motion';
import { Cpu, Lock } from 'lucide-react';
import Logo from './Logo';

const HomePage = ({ onNavigate }) => {
  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-6 md:px-10 py-16">
      {/* Logo */}
      <motion.div
        initial={{ opacity: 0, y: -24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, ease: [0.22, 0.61, 0.36, 1] }}
        className="mb-14 md:mb-16"
      >
        <Logo size={96} />
      </motion.div>

      {/* Gateway Cards */}
      <div className="flex flex-col md:flex-row gap-8 md:gap-12 w-full max-w-5xl">
        {/* The Engine Card */}
        <motion.button
          initial={{ opacity: 0, x: -40 }}
          animate={{ opacity: 1, x: 0 }}
          whileHover={{ x: -4 }}
          whileTap={{ x: -2 }}
          transition={{
            duration: 0.55,
            delay: 0.18,
            ease: [0.33, 1, 0.68, 1],
          }}
          onClick={() => onNavigate('engine')}
          className="flex-1 group relative bg-surface/40 md:bg-surface border border-border
                     hover:bg-surface-highlight/80
                     transition-colors duration-300 p-10 md:p-14 lg:p-16
                     focus:outline-none focus-visible:border-primary/50"
        >
          <div className="flex flex-col items-center text-center">
            <div className="w-14 h-14 flex items-center justify-center mb-7
                          border border-border/80 bg-background/40
                          transition-colors duration-300">
              <Cpu
                size={30}
                className="text-text-dim group-hover:text-primary transition-colors duration-300"
              />
            </div>

            <h2 className="font-mono text-base md:text-lg lg:text-xl tracking-[0.35em] uppercase text-text mb-3">
              The Engine
            </h2>

            <p className="font-mono text-[0.7rem] md:text-xs tracking-[0.25em] text-text-dim uppercase">
              Analyze legacy logic
            </p>
          </div>

          {/* Corner accents - restrained */}
          <div
            className="pointer-events-none absolute inset-0 border border-border/60"
            aria-hidden="true"
          >
            <div className="absolute top-0 left-0 w-4 h-4 border-t border-l border-border/80" />
            <div className="absolute bottom-0 right-0 w-4 h-4 border-b border-r border-border/80" />
          </div>
        </motion.button>

        {/* The Vault Card */}
        <motion.button
          initial={{ opacity: 0, x: 40 }}
          animate={{ opacity: 1, x: 0 }}
          whileHover={{ y: -4, scale: 1.01 }}
          whileTap={{ y: -1, scale: 1.005 }}
          transition={{
            duration: 0.7,
            delay: 0.26,
            ease: [0.22, 0.8, 0.2, 1],
          }}
          onClick={() => onNavigate('vault')}
          className="flex-1 group relative bg-surface/40 md:bg-surface border border-border
                     hover:bg-surface-highlight/80
                     transition-colors duration-300 p-10 md:p-14 lg:p-16
                     focus:outline-none focus-visible:border-primary/50"
        >
          <div className="flex flex-col items-center text-center">
            <div className="w-14 h-14 flex items-center justify-center mb-7
                          border border-border/80 bg-background/40
                          transition-colors duration-300">
              <Lock
                size={30}
                className="text-text-dim group-hover:text-primary transition-colors duration-300"
              />
            </div>

            <h2 className="font-mono text-base md:text-lg lg:text-xl tracking-[0.35em] uppercase text-text mb-3">
              The Vault
            </h2>

            <p className="font-mono text-[0.7rem] md:text-xs tracking-[0.25em] text-text-dim uppercase">
              Stored analyses & exports
            </p>
          </div>

          {/* Corner accents - restrained */}
          <div
            className="pointer-events-none absolute inset-0 border border-border/60"
            aria-hidden="true"
          >
            <div className="absolute top-0 right-0 w-4 h-4 border-t border-r border-border/80" />
            <div className="absolute bottom-0 left-0 w-4 h-4 border-b border-l border-border/80" />
          </div>
        </motion.button>
      </div>

      {/* Footer */}
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.5, ease: [0.25, 0.8, 0.25, 1] }}
        className="mt-14 md:mt-16 text-center"
      >
        <p className="font-mono text-[0.7rem] md:text-xs tracking-[0.25em] text-text-dim uppercase">
          Architectural Integrity · Institutional Security
        </p>
      </motion.div>
    </div>
  );
};

export default HomePage;
