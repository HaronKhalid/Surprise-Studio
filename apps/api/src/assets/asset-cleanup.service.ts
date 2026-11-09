import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageProvider } from '../storage/storage.provider';
import { allKeysForAsset } from './asset-keys';

type AssetRef = { id: string; storageKey: string };

/**
 * Permanently removes photos. Files are deleted BEFORE their database rows: if storage fails the
 * rows survive, so the maintenance job can find and retry them. The reverse order would orphan
 * files that nothing references and nothing would ever delete.
 */
@Injectable()
export class AssetCleanupService {
  constructor(private readonly prisma: PrismaService, private readonly storage: StorageProvider) {}

  async deleteAssets(assets: AssetRef[]): Promise<number> {
    if (assets.length === 0) return 0;
    await this.storage.deleteObjects(assets.flatMap(allKeysForAsset));
    const { count } = await this.prisma.asset.deleteMany({ where: { id: { in: assets.map((a) => a.id) } } });
    return count;
  }

  async deleteForSurprises(surpriseIds: string[]): Promise<number> {
    if (surpriseIds.length === 0) return 0;
    const assets = await this.prisma.asset.findMany({
      where: { surpriseId: { in: surpriseIds } },
      select: { id: true, storageKey: true },
    });
    return this.deleteAssets(assets);
  }

  async deleteForUser(userId: string): Promise<number> {
    const assets = await this.prisma.asset.findMany({
      where: { surprise: { userId } },
      select: { id: true, storageKey: true },
    });
    return this.deleteAssets(assets);
  }
}
