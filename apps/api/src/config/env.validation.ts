/**
 * Fails fast at startup on a missing or unsafe configuration, instead of discovering it on the
 * first request (or never, as with a weak secret). Used by ConfigModule.forRoot({ validate }).
 *
 * Blank values count as unset: .env.example ships optional variables blank.
 */
const REQUIRED = ['DATABASE_URL', 'STORAGE_ENDPOINT', 'STORAGE_BUCKET', 'STORAGE_ACCESS_KEY', 'STORAGE_SECRET_KEY'] as const;
const KNOWN_DEV_STORAGE_KEYS = ['minioadmin', 'rustfsadmin'];

export function validateEnv(env: Record<string, unknown>): Record<string, unknown> {
  const errors: string[] = [];
  const get = (key: string) => (typeof env[key] === 'string' ? (env[key] as string).trim() : '');
  const production = get('NODE_ENV') === 'production';

  for (const key of REQUIRED) if (!get(key)) errors.push(`${key} is required`);

  // Production needs real entropy; development just needs to not be empty.
  const minSecret = production ? 32 : 16;
  for (const key of ['JWT_SECRET', 'JWT_REFRESH_SECRET']) {
    if (get(key).length < minSecret) errors.push(`${key} must be at least ${minSecret} characters`);
  }
  if (get('JWT_SECRET') && get('JWT_SECRET') === get('JWT_REFRESH_SECRET')) {
    errors.push('JWT_SECRET and JWT_REFRESH_SECRET must be different');
  }

  for (const key of ['PORT', 'TRUST_PROXY']) {
    if (get(key) && !/^\d+$/.test(get(key))) errors.push(`${key} must be a whole number`);
  }

  if (production) {
    const origins = get('CORS_ORIGIN').split(',').map((o) => o.trim()).filter(Boolean);
    if (origins.length === 0 || origins.includes('*')) {
      errors.push('CORS_ORIGIN must list the allowed web origins in production (not blank or *)');
    }
    if (KNOWN_DEV_STORAGE_KEYS.includes(get('STORAGE_ACCESS_KEY')) || KNOWN_DEV_STORAGE_KEYS.includes(get('STORAGE_SECRET_KEY'))) {
      errors.push('STORAGE_* still holds the local development credentials');
    }
    if (!get('TRUST_PROXY')) {
      // Not an error (a deployment may face the internet directly) but easy to get wrong, so say so.
      // eslint-disable-next-line no-console
      console.warn('TRUST_PROXY is not set: behind a load balancer every client will share one rate-limit bucket.');
    }
  }

  if (errors.length) throw new Error(`Invalid configuration:\n - ${errors.join('\n - ')}`);
  return env;
}
