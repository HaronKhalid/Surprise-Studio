import { IsIn, IsInt, IsUUID, Max, Min } from 'class-validator';
import { ALLOWED_MIME_TYPES, MAX_UPLOAD_BYTES } from '../image-validation';

export class UploadUrlDto {
  @IsUUID() surpriseId!: string;
  @IsIn(ALLOWED_MIME_TYPES) mimeType!: (typeof ALLOWED_MIME_TYPES)[number];
  @IsInt() @Min(1) @Max(MAX_UPLOAD_BYTES) size!: number;
}

export class CompleteUploadDto {
  @IsUUID() assetId!: string;
}

export class OrderDto {
  @IsInt() @Min(0) @Max(1000) sortOrder!: number;
}
