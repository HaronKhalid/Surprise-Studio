'use client';

import { useEffect, useRef, type ReactNode } from 'react';
import { oncePerSession, track } from '@/lib/analytics';

/**
 * Counts a view from the browser, not the server: link-preview bots (WhatsApp, Facebook, search
 * crawlers) fetch the HTML but do not run JavaScript, so they do not inflate the numbers.
 */
export function ViewBeacon({ slug, template }: { slug: string; template: string }) {
  useEffect(() => {
    oncePerSession(`opened:${slug}`, () => track('public_page_opened', slug, { template }));
  }, [slug, template]);
  return null;
}

/** Fires when the visitor reaches the footer: "watched it to the end". */
export function EndBeacon({ slug, template }: { slug: string; template: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el || !('IntersectionObserver' in window)) return;
    const io = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      oncePerSession(`completed:${slug}`, () => track('public_view_completed', slug, { template }));
      io.disconnect();
    });
    io.observe(el);
    return () => io.disconnect();
  }, [slug, template]);
  return <div ref={ref} aria-hidden="true" />;
}

/** A normal link that also reports the click (the "create your own" viral loop). */
export function TrackedLink({
  slug,
  step,
  className,
  href,
  children,
}: {
  slug: string;
  step: string;
  className?: string;
  href: string;
  children: ReactNode;
}) {
  return (
    <a href={href} className={className} onClick={() => track('cta_clicked', slug, { step })}>
      {children}
    </a>
  );
}
