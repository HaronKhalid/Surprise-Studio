/** Retention policy in one place, so it is easy to review and change. */
export const RETENTION = {
  /** An upload URL lives 5 minutes; anything unconfirmed after this is abandoned. */
  pendingUploadMinutes: 60,
  /** Deleted surprises are kept this long (their photos are erased immediately) before the row goes. */
  deletedSurpriseDays: 30,
  /** Revoked refresh tokens are kept briefly so reuse of a stolen token can still be detected. */
  revokedRefreshTokenDays: 7,
  /** Analytics events carry no personal data; keep about 13 months for year-on-year comparison. */
  eventDays: 400,
} as const;

const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;

export function cutoffs(now: Date) {
  const ago = (ms: number) => new Date(now.getTime() - ms);
  return {
    pendingUploads: ago(RETENTION.pendingUploadMinutes * MINUTE),
    deletedSurprises: ago(RETENTION.deletedSurpriseDays * DAY),
    revokedRefreshTokens: ago(RETENTION.revokedRefreshTokenDays * DAY),
    events: ago(RETENTION.eventDays * DAY),
  };
}
