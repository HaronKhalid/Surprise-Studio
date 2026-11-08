import { cache } from 'react';
import type { PublicSurprise } from './types';

const API_URL = (process.env.API_URL ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1').replace(/\/$/, '');

/** Same shape the API accepts, so obviously-bad slugs never cost an API call. */
const SLUG_PATTERN = /^[A-Za-z0-9_-]{6,32}$/;

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
