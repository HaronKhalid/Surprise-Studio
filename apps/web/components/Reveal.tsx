'use client';

import { useEffect, useRef, type ReactNode } from 'react';

/**
 * Fades content in as it scrolls into view. Progressive enhancement: content is fully visible in the
 * server HTML and with JavaScript off. It is only hidden after hydration, and only if it is below the
 * fold and the visitor has not asked for reduced motion.
 */
export function Reveal({ children, className = '', delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced || !('IntersectionObserver' in window) || el.getBoundingClientRect().top < window.innerHeight) return;

    el.style.setProperty('--reveal-delay', `${delay}ms`);
    el.classList.add('reveal-armed');
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          el.classList.add('is-visible');
          io.disconnect();
        }
      },
      { rootMargin: '0px 0px -10% 0px', threshold: 0.05 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [delay]);

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
