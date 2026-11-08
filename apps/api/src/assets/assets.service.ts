import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Asset } from '@prisma/client';
import { nanoid } from 'nanoid';
import sharp from 'sharp';
import { PrismaService } from '../prisma/prisma.service';
import { StorageProvider } from '../storage/storage.provider';
import { UploadUrlDto } from './dto/asset.dto';
import {
  MAX_DIMENSION,
  MAX_PHOTOS_PER_SURPRISE,
  MAX_UPLOAD_BYTES,
  MIN_DIMENSION,
  VARIANTS,
  detectMime,
  displayedSize,
} from './image-validation';

const UPLOAD_URL_TTL_SECONDS = 300;

/**
 * Processed, publicly readable files live under assets/; raw uploads are private and short-lived.
 * The public key is random, not derived from database ids, because it ends up in public image URLs.
 */
const newBaseKey = () => `assets/${nanoid(24)}`;
const uploadKey = (assetId: string) => `uploads/${assetId}`;
const variantKeys = (key: string) => VARIANTS.map((v) => `${key}/${v.name}.webp`);

@Injectable()
export class AssetsService {
  constructor(private readonly prisma: PrismaService, private readonly storage: StorageProvider) {}

  async createUploadUrl(userId: string, dto: UploadUrlDto) {
    await this.assertSurpriseOwner(userId, dto.surpriseId);
    // Confirmed photos plus uploads still in flight. An abandoned upload stops counting once its
    // URL has expired, so it cannot lock a user out of adding photos.
    const inFlightSince = new Date(Date.now() - UPLOAD_URL_TTL_SECONDS * 1000);
    const count = await this.prisma.asset.count({
      where: { surpriseId: dto.surpriseId, OR: [{ confirmed: true }, { createdAt: { gt: inFlightSince } }] },
    });
    if (count >= MAX_PHOTOS_PER_SURPRISE) throw this.photoLimit();

    const asset = await this.prisma.asset.create({
      data: {
        surpriseId: dto.surpriseId,
        storageKey: newBaseKey(),
        mimeType: dto.mimeType,
        size: dto.size,
        sortOrder: count,
      },
    });

    const uploadUrl = await this.storage.createUploadUrl(
      uploadKey(asset.id),
      dto.mimeType,
      dto.size,
      UPLOAD_URL_TTL_SECONDS,
    );
    return { assetId: asset.id, uploadUrl, expiresIn: UPLOAD_URL_TTL_SECONDS, method: 'PUT', headers: { 'Content-Type': dto.mimeType } };
  }

  /** Validates what was actually uploaded, then generates optimised variants. */
  async complete(userId: string, assetId: string) {
    const asset = await this.findOwned(userId, assetId);
    if (asset.confirmed) return this.present(asset);

    const raw = uploadKey(asset.id);
    try {
      // Re-check at the point that actually makes a photo count (several URLs may have been issued).
      const confirmed = await this.prisma.asset.count({ where: { surpriseId: asset.surpriseId, confirmed: true } });
      if (confirmed >= MAX_PHOTOS_PER_SURPRISE) throw this.photoLimit();

      const head = await this.storage.head(raw);
      if (!head) throw this.invalid('UPLOAD_NOT_FOUND', 'The file was not uploaded');
      if (head.size > MAX_UPLOAD_BYTES) throw this.invalid('FILE_TOO_LARGE', 'File is too large');
      if (head.size !== asset.size) throw this.invalid('SIZE_MISMATCH', 'Uploaded size does not match');

      const buf = await this.storage.getObject(raw);
      const real = detectMime(buf);
      if (!real) throw this.invalid('INVALID_FILE_TYPE', 'Only JPEG, PNG and WebP images are allowed');
      if (real !== asset.mimeType) throw this.invalid('MIME_MISMATCH', 'File type does not match its declared type');

      const meta = await sharp(buf).metadata().catch(() => {
        throw this.invalid('INVALID_IMAGE', 'The file is not a readable image');
      });
      const size = displayedSize(meta);
      if (!size || Math.min(size.width, size.height) < MIN_DIMENSION || Math.max(size.width, size.height) > MAX_DIMENSION) {
        throw this.invalid('INVALID_DIMENSIONS', `Image sides must be between ${MIN_DIMENSION} and ${MAX_DIMENSION}px`);
      }
      const { width, height } = size;

      // rotate() applies EXIF orientation; re-encoding drops EXIF (including GPS location).
      for (const v of VARIANTS) {
        const out = await sharp(buf)
          .rotate()
          .resize({ width: v.width, withoutEnlargement: true })
          .webp({ quality: 80 })
          .toBuffer();
        await this.storage.putObject(`${asset.storageKey}/${v.name}.webp`, out, 'image/webp');
      }

      await this.storage.deleteObjects([raw]);
      const updated = await this.prisma.asset.update({
        where: { id: asset.id },
        data: { confirmed: true, width, height },
      });
      return this.present(updated);
    } catch (err) {
      // Failed validation: drop the record and the raw file so nothing unvalidated lingers.
      await this.storage.deleteObjects([raw, ...variantKeys(asset.storageKey)]).catch(() => undefined);
      await this.prisma.asset.delete({ where: { id: asset.id } }).catch(() => undefined);
      throw err;
    }
  }

  async remove(userId: string, assetId: string) {
    const asset = await this.findOwned(userId, assetId);
    await this.storage.deleteObjects([uploadKey(asset.id), ...variantKeys(asset.storageKey)]);
    await this.prisma.asset.delete({ where: { id: asset.id } });
  }

  async setOrder(userId: string, assetId: string, sortOrder: number) {
    await this.findOwned(userId, assetId);
    return this.present(await this.prisma.asset.update({ where: { id: assetId }, data: { sortOrder } }));
  }

  async list(userId: string, surpriseId: string) {
    await this.assertSurpriseOwner(userId, surpriseId);
    const assets = await this.prisma.asset.findMany({
      where: { surpriseId, confirmed: true },
      orderBy: { sortOrder: 'asc' },
    });
    return assets.map((a) => this.present(a));
  }

  private present(a: Asset) {
    return {
      id: a.id,
      width: a.width,
      height: a.height,
      sortOrder: a.sortOrder,
      confirmed: a.confirmed,
      urls: Object.fromEntries(VARIANTS.map((v) => [v.name, this.storage.publicUrl(`${a.storageKey}/${v.name}.webp`)])),
    };
  }

  private invalid(code: string, message: string) {
    return new BadRequestException({ code, message });
  }

  private photoLimit() {
    return this.invalid('PHOTO_LIMIT_REACHED', `A surprise can have at most ${MAX_PHOTOS_PER_SURPRISE} photos`);
  }

  private async assertSurpriseOwner(userId: string, surpriseId: string) {
    const s = await this.prisma.surprise.findUnique({ where: { id: surpriseId }, select: { userId: true, status: true } });
    if (!s || s.status === 'DELETED') {
      throw new NotFoundException({ code: 'SURPRISE_NOT_FOUND', message: 'Surprise not found' });
    }
    if (s.userId !== userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'You do not have access to this surprise' });
    }
  }

  private async findOwned(userId: string, assetId: string) {
    const asset = await this.prisma.asset.findUnique({ where: { id: assetId }, include: { surprise: { select: { userId: true } } } });
    if (!asset) throw new NotFoundException({ code: 'ASSET_NOT_FOUND', message: 'Asset not found' });
    if (asset.surprise.userId !== userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'You do not have access to this asset' });
    }
    return asset;
  }
}
