import { createHash } from 'crypto';

export const PREVIEW_TTL_SECONDS = 10 * 60;

/**
 * Preview tokens are signed with a key derived from (not equal to) the access-token secret.
 * A preview token therefore can never be accepted as an access token, or the reverse, even though
 * both are JWTs: they simply do not verify under each other's key.
 */
export const previewSecret = (jwtSecret: string) => createHash('sha256').update(`preview:${jwtSecret}`).digest('hex');
