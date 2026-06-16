'use client';

import { motion } from 'framer-motion';

interface FadeInProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  /** Pixels to slide up from on enter. */
  y?: number;
}

// Scroll/mount reveal — replaces the common "everything just pops in instantly" feel
// of plain Tailwind sites with a staggered, premium-feeling entrance.
export function FadeIn({ children, className, delay = 0, y = 16 }: FadeInProps) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.5, delay, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </motion.div>
  );
}
