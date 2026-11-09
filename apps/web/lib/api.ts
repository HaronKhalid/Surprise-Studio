import { cache } from 'react';
import type { PublicSurprise } from './types';

const API_URL = (process.env.API_URL ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1').replace(/\/$/, '');

/** Same shape the API accepts, so obviously-bad slugs never cost an API call. */
const SLUG_PATTERN = /^[A-Za-z0-9_-]{6,32}$/;

const TOKEN_PATTERN = /^[A-Za-z0-9._-]{20,1000}$/;

/**
 * The creator's draft, authorised by a short-lived signed token from the creator app. Same
 * not-available semantics as getSurprise: null for a bad or expired token, throw otherwise.
 */
export const getPreview = cache(async (token: string): Promise<PublicSurprise | null> => {
  if (!TOKEN_PATTERN.test(token)) return null;
  const res = await fetch(`${API_URL}/public/previews/${encodeURIComponent(token)}`, { cache: 'no-store' });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`API responded ${res.status}`);
  const body = (await res.json()) as { success: boolean; data?: PublicSurprise };
  return body.success && body.data ? body.data : null;
});

/**
 * Fetches a published surprise. Returns null when it is not available (unpublished, deleted,
 * private, unknown). Any other failure throws so the error boundary shows a retry, rather than
 * telling a recipient their surprise does not exist because of a hiccup.
 *
 * Wrapped in `cache` so generateMetadata and the page share one request.
 */
export const getSurprise = cache(async (slug: string): Promise<PublicSurprise | null> => {
  if (!SLUG_PATTERN.test(slug)) return null;
  const res = await fetch(`${API_URL}/public/surprises/${encodeURIComponent(slug)}`, { cache: 'no-store' });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`API responded ${res.status}`);
  const body = (await res.json()) as { success: boolean; data?: PublicSurprise };
  return body.success && body.data ? body.data : null;
});
