import {
  DeleteObjectsCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { StorageProvider } from './storage.provider';

const DELETE_BATCH = 1000;

@Injectable()
export class S3StorageProvider extends StorageProvider {
  private readonly bucket: string;
  private readonly client: S3Client;
  /** Signs with the host clients can reach (e.g. 10.0.2.2 for the Android emulator). */
  private readonly signingClient: S3Client;
  private readonly publicBase: string;

  constructor(config: ConfigService) {
    super();
    this.bucket = config.getOrThrow('STORAGE_BUCKET');
    const endpoint = config.getOrThrow<string>('STORAGE_ENDPOINT');
    // Optional vars are documented as blank in .env.example, so blank must mean "unset".
    // (`??` would keep '' and the AWS SDK would then silently fall back to real AWS.)
    const optional = (name: string) => config.get<string>(name)?.trim() || undefined;
    const make = (ep: string) =>
      new S3Client({
        endpoint: ep,
        region: optional('STORAGE_REGION') ?? 'auto',
        forcePathStyle: true,
        credentials: {
          accessKeyId: config.getOrThrow('STORAGE_ACCESS_KEY'),
          secretAccessKey: config.getOrThrow('STORAGE_SECRET_KEY'),
        },
      });
    this.client = make(endpoint);
    this.signingClient = make(optional('STORAGE_PUBLIC_ENDPOINT') ?? endpoint);
    this.publicBase = (optional('STORAGE_PUBLIC_URL') ?? `${endpoint}/${this.bucket}`).replace(/\/$/, '');
  }

  createUploadUrl(key: string, contentType: string, contentLength: number, expiresInSeconds: number) {
    return getSignedUrl(
      this.signingClient,
      new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType, ContentLength: contentLength }),
      { expiresIn: expiresInSeconds },
    );
  }

  async head(key: string) {
    try {
      const r = await this.client.send(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return { size: r.ContentLength ?? 0 };
    } catch {
      return null;
    }
  }

  async getObject(key: string) {
    const r = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    return Buffer.from(await r.Body!.transformToByteArray());
  }

  async putObject(key: string, body: Buffer, contentType: string) {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
  }

  /**
   * Deleting a missing key is not an error. S3 caps one request at 1000 keys, and reports per-key
   * failures in the response body rather than by throwing, so those are surfaced here: callers
   * delete database rows after this returns, and must not do that if files are still there.
   */
  async deleteObjects(keys: string[]) {
    for (let i = 0; i < keys.length; i += DELETE_BATCH) {
      const batch = keys.slice(i, i + DELETE_BATCH);
      const res = await this.client.send(
        new DeleteObjectsCommand({ Bucket: this.bucket, Delete: { Objects: batch.map((Key) => ({ Key })), Quiet: true } }),
      );
      if (res.Errors?.length) {
        const first = res.Errors[0];
        throw new Error(`Failed to delete ${res.Errors.length} object(s), e.g. ${first.Key}: ${first.Code} ${first.Message ?? ''}`.trim());
      }
    }
  }

  publicUrl(key: string) {
    return `${this.publicBase}/${key}`;
  }
}
