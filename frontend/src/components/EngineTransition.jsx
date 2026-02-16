import React from 'react';
import { motion } from 'framer-motion';
import { Cpu, Zap } from 'lucide-react';

const EngineTransition = () => {
  const heavySpring = {
    type: "spring",
    stiffness: 100,
    damping: 18,
  };

  const slowReveal = {
    duration: 0.8,
    ease: [0.16, 1, 0.3, 1],
  };

  return (
    <div className="fixed inset-0 bg-background z-50 overflow-hidden">

      {/* Initial flash */}
      <motion.div
        initial={{ opacity: 0.3 }}
        animate={{ opacity: 0 }}
        transition={{ duration: 0.4 }}
        className="absolute inset-0 bg-primary/10 z-50"
      />

      {/* Horizontal scan lines - sweep effect */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.2 }}
        className="absolute inset-0 pointer-events-none z-0"
      >
        {[...Array(30)].map((_, i) => (
          <motion.div
            key={i}
            initial={{ scaleX: 0, opacity: 0 }}
            animate={{ scaleX: 1, opacity: 0.5 }}
            transition={{ duration: 0.6, delay: i * 0.015, ease: [0.16, 1, 0.3, 1] }}
            className="h-px bg-primary/10 origin-left"
            style={{ marginTop: `${i * 3.33}%` }}
          />
        ))}
      </motion.div>

      {/* Panel 1 - Top Left */}
      <motion.div
        initial={{ x: '-130%', rotate: -12, scale: 0.85 }}
        animate={{ x: 0, rotate: 0, scale: 1 }}
        transition={{ ...heavySpring, delay: 0.15 }}
        className="absolute top-0 left-0 w-1/2 h-1/2 bg-surface border-r-2 border-b-2 border-primary/30 overflow-hidden"
      >
        <div className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: 'linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)',
            backgroundSize: '16px 16px'
          }}
        />
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="absolute top-4 left-4 font-mono text-[10px] tracking-[0.3em] text-primary/40"
        >
          SECTOR-01
        </motion.div>
        <div className="absolute bottom-8 right-8 w-6 h-6 border-2 border-primary/30" />
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 1.0, type: "spring" }}
          className="absolute bottom-9 right-9 w-4 h-4 bg-primary/20"
        />
      </motion.div>

      {/* Panel 2 - Top Right */}
      <motion.div
        initial={{ x: '130%', rotate: 12, scale: 0.85 }}
        animate={{ x: 0, rotate: 0, scale: 1 }}
        transition={{ ...heavySpring, delay: 0.25 }}
        className="absolute top-0 right-0 w-1/2 h-1/2 bg-surface border-l-2 border-b-2 border-primary/30 overflow-hidden"
      >
        <div className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: 'linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)',
            backgroundSize: '16px 16px'
          }}
        />
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.9 }}
          className="absolute top-4 right-4 font-mono text-[10px] tracking-[0.3em] text-primary/40"
        >
          SECTOR-02
        </motion.div>
        <div className="absolute bottom-8 left-8 w-6 h-6 border-2 border-primary/30" />
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 1.1, type: "spring" }}
          className="absolute bottom-9 left-9 w-4 h-4 bg-primary/20"
        />
      </motion.div>

      {/* Panel 3 - Bottom Left */}
      <motion.div
        initial={{ y: '130%', rotate: 10, scale: 0.85 }}
        animate={{ y: 0, rotate: 0, scale: 1 }}
        transition={{ ...heavySpring, delay: 0.35 }}
        className="absolute bottom-0 left-0 w-1/2 h-1/2 bg-surface border-r-2 border-t-2 border-primary/30 overflow-hidden"
      >
        <div className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: 'linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)',
            backgroundSize: '16px 16px'
          }}
        />
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.0 }}
          className="absolute bottom-4 left-4 font-mono text-[10px] tracking-[0.3em] text-primary/40"
        >
          SECTOR-03
        </motion.div>
        <div className="absolute top-8 right-8 w-6 h-6 border-2 border-primary/30" />
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 1.2, type: "spring" }}
          className="absolute top-9 right-9 w-4 h-4 bg-primary/20"
        />
      </motion.div>

      {/* Panel 4 - Bottom Right */}
      <motion.div
        initial={{ y: '-130%', rotate: -10, scale: 0.85 }}
        animate={{ y: 0, rotate: 0, scale: 1 }}
        transition={{ ...heavySpring, delay: 0.45 }}
        className="absolute bottom-0 right-0 w-1/2 h-1/2 bg-surface border-l-2 border-t-2 border-primary/30 overflow-hidden"
      >
        <div className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage: 'linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)',
            backgroundSize: '16px 16px'
          }}
        />
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.1 }}
          className="absolute bottom-4 right-4 font-mono text-[10px] tracking-[0.3em] text-primary/40"
        >
          SECTOR-04
        </motion.div>
        <div className="absolute top-8 left-8 w-6 h-6 border-2 border-primary/30" />
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 1.3, type: "spring" }}
          className="absolute top-9 left-9 w-4 h-4 bg-primary/20"
        />
      </motion.div>

      {/* Center alignment crosshairs */}
      <motion.div
        initial={{ scaleX: 0 }}
        animate={{ scaleX: 1 }}
        transition={{ ...slowReveal, delay: 0.9 }}
        className="absolute top-1/2 left-0 right-0 h-px bg-primary/40 origin-center"
      />
      <motion.div
        initial={{ scaleY: 0 }}
        animate={{ scaleY: 1 }}
        transition={{ ...slowReveal, delay: 0.95 }}
        className="absolute left-1/2 top-0 bottom-0 w-px bg-primary/40 origin-center"
      />

      {/* Outer targeting diamonds */}
      <motion.div
        initial={{ scale: 3, opacity: 0, rotate: 45 }}
        animate={{ scale: 1, opacity: 1, rotate: 45 }}
        transition={{ duration: 1, delay: 1.0, ease: [0.16, 1, 0.3, 1] }}
        className="absolute inset-0 flex items-center justify-center z-10 pointer-events-none"
      >
        <div className="w-56 h-56 border border-primary/15" />
      </motion.div>
      <motion.div
        initial={{ scale: 2.5, opacity: 0, rotate: 45 }}
        animate={{ scale: 1, opacity: 1, rotate: 45 }}
        transition={{ duration: 0.9, delay: 1.1, ease: [0.16, 1, 0.3, 1] }}
        className="absolute inset-0 flex items-center justify-center z-10 pointer-events-none"
      >
        <div className="w-44 h-44 border border-primary/25" />
      </motion.div>

      {/* Corner targeting markers */}
      {[
        { pos: 'top-[15%] left-[15%]', rotate: 0 },
        { pos: 'top-[15%] right-[15%]', rotate: 90 },
        { pos: 'bottom-[15%] right-[15%]', rotate: 180 },
        { pos: 'bottom-[15%] left-[15%]', rotate: 270 },
      ].map((corner, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 1.2 + i * 0.1, type: "spring", stiffness: 200 }}
          className={`absolute ${corner.pos} w-8 h-8`}
          style={{ transform: `rotate(${corner.rotate}deg)` }}
        >
          <div className="w-full h-full border-t-2 border-l-2 border-primary/50" />
        </motion.div>
      ))}

      {/* CENTER ASSEMBLY - THE BIG REVEAL */}
      <motion.div
        initial={{ scale: 0, rotate: -270, opacity: 0 }}
        animate={{ scale: 1, rotate: 0, opacity: 1 }}
        transition={{
          duration: 1.2,
          delay: 1.4,
          ease: [0.16, 1, 0.3, 1],
        }}
        className="absolute inset-0 flex items-center justify-center z-20"
      >
        <div className="relative">
          {/* Glow ring */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: [0, 0.5, 0.3] }}
            transition={{ delay: 2.0, duration: 1 }}
            className="absolute -inset-8 border border-primary/20 rounded-full"
          />

          {/* Outer frame */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.8, duration: 0.5 }}
            className="absolute -inset-6 border-2 border-primary/15"
          />

          {/* Main housing */}
          <div className="w-40 h-40 border-2 border-primary/50 flex items-center justify-center bg-background relative">
            {/* Inner ring */}
            <motion.div
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ delay: 1.7, duration: 0.6 }}
              className="w-32 h-32 border border-primary/70 flex items-center justify-center"
            >
              {/* Core housing */}
              <motion.div
                initial={{ scale: 0, rotate: 90 }}
                animate={{ scale: 1, rotate: 0 }}
                transition={{ delay: 1.9, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                className="w-24 h-24 border-2 border-primary flex items-center justify-center bg-primary/5"
              >
                {/* THE CORE */}
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: 2.2, type: "spring", stiffness: 150, damping: 12 }}
                  className="relative"
                >
                  <Cpu size={36} className="text-primary" />
                  <motion.div
                    animate={{ opacity: [0.5, 1, 0.5] }}
                    transition={{ duration: 2, repeat: Infinity }}
                    className="absolute inset-0 flex items-center justify-center"
                  >
                    <Zap size={16} className="text-primary" />
                  </motion.div>
                </motion.div>
              </motion.div>
            </motion.div>

            {/* Power conduits */}
            <motion.div
              initial={{ scaleY: 0 }}
              animate={{ scaleY: 1 }}
              transition={{ delay: 2.0, duration: 0.5 }}
              className="absolute top-0 left-1/2 -translate-x-1/2 w-px h-6 bg-primary/60 origin-bottom"
            />
            <motion.div
              initial={{ scaleY: 0 }}
              animate={{ scaleY: 1 }}
              transition={{ delay: 2.05, duration: 0.5 }}
              className="absolute bottom-0 left-1/2 -translate-x-1/2 w-px h-6 bg-primary/60 origin-top"
            />
            <motion.div
              initial={{ scaleX: 0 }}
              animate={{ scaleX: 1 }}
              transition={{ delay: 2.1, duration: 0.5 }}
              className="absolute left-0 top-1/2 -translate-y-1/2 w-6 h-px bg-primary/60 origin-right"
            />
            <motion.div
              initial={{ scaleX: 0 }}
              animate={{ scaleX: 1 }}
              transition={{ delay: 2.15, duration: 0.5 }}
              className="absolute right-0 top-1/2 -translate-y-1/2 w-6 h-px bg-primary/60 origin-left"
            />
          </div>

          {/* Heavy corner brackets */}
          <div className="absolute -top-3 -left-3 w-6 h-6 border-t-[3px] border-l-[3px] border-primary" />
          <div className="absolute -top-3 -right-3 w-6 h-6 border-t-[3px] border-r-[3px] border-primary" />
          <div className="absolute -bottom-3 -left-3 w-6 h-6 border-b-[3px] border-l-[3px] border-primary" />
          <div className="absolute -bottom-3 -right-3 w-6 h-6 border-b-[3px] border-r-[3px] border-primary" />

          {/* Status dots */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 2.3 }}
            className="absolute -right-10 top-1/2 -translate-y-1/2 flex flex-col gap-2"
          >
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                animate={{ opacity: [0.3, 1, 0.3] }}
                transition={{ duration: 1, repeat: Infinity, delay: i * 0.2 }}
                className="w-1.5 h-1.5 bg-primary"
              />
            ))}
          </motion.div>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 2.3 }}
            className="absolute -left-10 top-1/2 -translate-y-1/2 flex flex-col gap-2"
          >
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                animate={{ opacity: [0.3, 1, 0.3] }}
                transition={{ duration: 1, repeat: Infinity, delay: i * 0.2 + 0.5 }}
                className="w-1.5 h-1.5 bg-primary"
              />
            ))}
          </motion.div>
        </div>
      </motion.div>

      {/* FINAL STATUS DISPLAY */}
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 2.5, ease: [0.16, 1, 0.3, 1] }}
        className="absolute inset-x-0 bottom-[18%] flex flex-col items-center gap-6"
      >
        <div className="flex items-center gap-6">
          <motion.div
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="w-2 h-2 bg-primary"
          />
          <div className="flex flex-col items-center">
            <h2 className="font-mono text-base tracking-[0.6em] uppercase text-text font-medium">
              Engine Online
            </h2>
            <motion.div
              initial={{ scaleX: 0 }}
              animate={{ scaleX: 1 }}
              transition={{ delay: 2.8, duration: 0.6 }}
              className="w-full h-px bg-primary/50 mt-2"
            />
          </div>
          <motion.div
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ duration: 2, repeat: Infinity, delay: 1 }}
            className="w-2 h-2 bg-primary"
          />
        </div>
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2.9, duration: 0.5 }}
          className="font-mono text-[10px] tracking-[0.4em] uppercase text-text-dim"
        >
          All Systems Nominal
        </motion.p>
      </motion.div>
    </div>
  );
};

export default EngineTransition;
