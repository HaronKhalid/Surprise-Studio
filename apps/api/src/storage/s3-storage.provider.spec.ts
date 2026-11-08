import { ConfigService } from '@nestjs/config';
import { S3StorageProvider } from './s3-storage.provider';

const base = {
  STORAGE_ENDPOINT: 'http://localhost:9000',
  STORAGE_BUCKET: 'surprise-assets',
  STORAGE_ACCESS_KEY: 'test-key',
  STORAGE_SECRET_KEY: 'test-secret',
};

const make = (extra: Record<string, string> = {}) => new S3StorageProvider(new ConfigService({ ...base, ...extra }));

describe('S3StorageProvider config', () => {
  // .env.example ships these optional vars blank. A blank value must behave like an unset one:
  // `??` kept '' and the AWS SDK then signed URLs for real AWS instead of the configured endpoint.
  it.each([
    ['unset', {}],
    ['blank', { STORAGE_PUBLIC_ENDPOINT: '', STORAGE_PUBLIC_URL: '', STORAGE_REGION: '' }],
    ['whitespace', { STORAGE_PUBLIC_ENDPOINT: '  ', STORAGE_PUBLIC_URL: '  ', STORAGE_REGION: '  ' }],
  ])('signs upload URLs for the configured endpoint when optional vars are %s', async (_label, extra) => {
    const url = new URL(await make(extra).createUploadUrl('uploads/x', 'image/png', 123, 300));
    expect(url.origin).toBe('http://localhost:9000');
    expect(url.pathname).toBe('/surprise-assets/uploads/x');
  });

  it.each([
    ['unset', {}],
    ['blank', { STORAGE_PUBLIC_URL: '' }],
  ])('builds public URLs from endpoint + bucket when STORAGE_PUBLIC_URL is %s', (_label, extra) => {
    expect(make(extra).publicUrl('assets/a/b/thumb.webp')).toBe(
      'http://localhost:9000/surprise-assets/assets/a/b/thumb.webp',
    );
  });

  it('uses STORAGE_PUBLIC_ENDPOINT for signing and STORAGE_PUBLIC_URL for public links when set', async () => {
    const p = make({
      STORAGE_PUBLIC_ENDPOINT: 'http://10.0.2.2:9000',
      STORAGE_PUBLIC_URL: 'https://cdn.example.com/',
    });
    expect(new URL(await p.createUploadUrl('uploads/x', 'image/png', 123, 300)).origin).toBe('http://10.0.2.2:9000');
    expect(p.publicUrl('assets/k')).toBe('https://cdn.example.com/assets/k');
  });
});
