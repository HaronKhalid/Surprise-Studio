import { cutoffs, RETENTION } from './retention';

describe('cutoffs', () => {
  const now = new Date('2026-06-15T12:00:00.000Z');
  const c = cutoffs(now);

  it('computes each cutoff relative to now', () => {
    expect(c.pendingUploads.toISOString()).toBe('2026-06-15T11:00:00.000Z');
    expect(c.deletedSurprises.toISOString()).toBe('2026-05-16T12:00:00.000Z');
    expect(c.revokedRefreshTokens.toISOString()).toBe('2026-06-08T12:00:00.000Z');
    expect(c.events.getTime()).toBe(now.getTime() - 400 * 24 * 3600_000);
  });

  it('does not mutate the input date', () => {
    expect(now.toISOString()).toBe('2026-06-15T12:00:00.000Z');
  });

  it('keeps pending uploads longer than the 5 minute upload URL lifetime', () => {
    // A cleanup that is more eager than the URL would delete uploads still in progress.
    expect(RETENTION.pendingUploadMinutes).toBeGreaterThan(5);
  });
});
