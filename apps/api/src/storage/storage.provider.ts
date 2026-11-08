/** Provider-agnostic object storage. Implement this to move off S3-compatible storage. */
export abstract class StorageProvider {
  /** Presigned URL the client PUTs the file to directly. */
  abstract createUploadUrl(key: string, contentType: string, contentLength: number, expiresInSeconds: number): Promise<string>;
  abstract head(key: string): Promise<{ size: number } | null>;
  abstract getObject(key: string): Promise<Buffer>;
  abstract putObject(key: string, body: Buffer, contentType: string): Promise<void>;
  abstract deleteObjects(keys: string[]): Promise<void>;
  /** Public CDN/bucket URL for keys under the public `assets/` prefix. */
  abstract publicUrl(key: string): string;
}
