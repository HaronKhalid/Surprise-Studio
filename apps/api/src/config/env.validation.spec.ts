import { validateEnv } from './env.validation';

const dev = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  JWT_SECRET: 'a'.repeat(20),
  JWT_REFRESH_SECRET: 'b'.repeat(20),
  STORAGE_ENDPOINT: 'http://localhost:9000',
  STORAGE_BUCKET: 'bucket',
  STORAGE_ACCESS_KEY: 'minioadmin',
  STORAGE_SECRET_KEY: 'minioadmin',
};
const prod = {
  ...dev,
  NODE_ENV: 'production',
  JWT_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'b'.repeat(40),
  STORAGE_ACCESS_KEY: 'AKIAREALKEY',
  STORAGE_SECRET_KEY: 'real-secret-value',
  CORS_ORIGIN: 'https://surprise.example.com',
  TRUST_PROXY: '1',
};

const problems = (env: Record<string, unknown>) => {
  try {
    validateEnv(env);
    return [];
  } catch (e) {
    return (e as Error).message.split('\n - ').slice(1);
  }
};

describe('validateEnv', () => {
  it('accepts a development configuration, including blank optional variables', () => {
    expect(problems({ ...dev, CORS_ORIGIN: '', STORAGE_PUBLIC_URL: '', PORT: '' })).toEqual([]);
  });

  it('accepts a production configuration', () => {
    expect(problems(prod)).toEqual([]);
  });

  it.each(['DATABASE_URL', 'STORAGE_ENDPOINT', 'STORAGE_BUCKET', 'STORAGE_ACCESS_KEY', 'STORAGE_SECRET_KEY', 'JWT_SECRET', 'JWT_REFRESH_SECRET'])(
    'requires %s (blank counts as missing)',
    (key) => {
      expect(problems({ ...dev, [key]: '' }).join()).toContain(key);
      expect(problems({ ...dev, [key]: '   ' }).join()).toContain(key);
      const { [key]: _omitted, ...rest } = dev as Record<string, string>;
      expect(problems(rest).join()).toContain(key);
    },
  );

  it('reports every problem at once', () => {
    expect(problems({}).length).toBeGreaterThanOrEqual(7);
  });

  it('rejects short secrets in production but allows 16+ characters in development', () => {
    expect(problems({ ...dev, JWT_SECRET: 'short' }).join()).toContain('at least 16');
    expect(problems({ ...prod, JWT_SECRET: 'a'.repeat(31) }).join()).toContain('at least 32');
  });

  it('rejects identical access and refresh secrets', () => {
    expect(problems({ ...dev, JWT_REFRESH_SECRET: dev.JWT_SECRET }).join()).toContain('must be different');
  });

  it('rejects a non-numeric PORT or TRUST_PROXY', () => {
    expect(problems({ ...dev, PORT: 'abc' }).join()).toContain('PORT');
    expect(problems({ ...dev, TRUST_PROXY: 'yes' }).join()).toContain('TRUST_PROXY');
  });

  it.each(['', '*', ' , '])('requires explicit CORS origins in production (%p)', (origin) => {
    expect(problems({ ...prod, CORS_ORIGIN: origin }).join()).toContain('CORS_ORIGIN');
  });

  it('does not require CORS_ORIGIN outside production', () => {
    expect(problems({ ...dev })).toEqual([]);
  });

  it('refuses the local development storage credentials in production', () => {
    expect(problems({ ...prod, STORAGE_ACCESS_KEY: 'minioadmin' }).join()).toContain('development credentials');
    expect(problems({ ...prod, STORAGE_SECRET_KEY: 'rustfsadmin' }).join()).toContain('development credentials');
  });
});
