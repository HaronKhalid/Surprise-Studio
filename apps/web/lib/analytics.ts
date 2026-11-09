'use client';

const API = (process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1').replace(/\/$/, '');

type EventType = 'public_page_opened' | 'public_view_completed' | 'cta_clicked';

/**
 * Privacy-conscious product analytics: sends an event name, the public slug and at most a couple
 * of short tokens. No cookies, no identifiers, nothing is stored about the visitor (the server
 * keeps no IP or user agent either). Honours Do Not Track. Failures are swallowed on purpose:
 * analytics must never affect the page.
 */
export function track(eventType: EventType, slug: string, metadata?: { template?: string; step?: string }) {
  if (typeof navigator === 'undefined' || navigator.doNotTrack === '1') return;
  fetch(`${API}/analytics/events`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ eventType, slug, metadata }),
    keepalive: true, // survives the page being closed or navigated away from
  }).catch(() => undefined);
}

/** Runs `fn` at most once per browser session for this key (reloads do not double count). */
export function oncePerSession(key: string, fn: () => void) {
  try {
    if (sessionStorage.getItem(key)) return;
    sessionStorage.setItem(key, '1');
  } catch {
    // Storage blocked (private mode): fall through and count it; a rare duplicate beats losing the event.
  }
  fn();
}
