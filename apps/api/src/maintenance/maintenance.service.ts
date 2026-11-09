import { Injectable, Logger } from '@nestjs/common';
import { SurpriseStatus } from '@prisma/client';
import { AssetCleanupService } from '../assets/asset-cleanup.service';
import { PrismaService } from '../prisma/prisma.service';
import { cutoffs } from './retention';

export interface MaintenanceReport {
  abandonedUploads: number;
  deletedSurpriseAssets: number;
  purgedSurprises: number;
  refreshTokens: number;
  events: number;
}

const BATCH = 500;

/**
 * Housekeeping that must happen eventually but not on a request. Every step is idempotent and
 * safe to run concurrently or repeatedly, so any scheduler (cron, Kubernetes CronJob, a platform
 * scheduler) can run it as often as it likes, even from several places at once.
 */
@Injectable()
export class MaintenanceService {
  private readonly logger = new Logger(MaintenanceService.name);

  constructor(private readonly prisma: PrismaService, private readonly cleanup: AssetCleanupService) {}

  async run(now = new Date()): Promise<MaintenanceReport> {
    const cut = cutoffs(now);
    const report: MaintenanceReport = { abandonedUploads: 0, deletedSurpriseAssets: 0, purgedSurprises: 0, refreshTokens: 0, events: 0 };

    // 1. Photos requested but never confirmed (user left, upload failed): remove rows and any raw file.
    report.abandonedUploads = await this.drain(() =>
      this.prisma.asset.findMany({
        where: { confirmed: false, createdAt: { lt: cut.pendingUploads } },
        select: { id: true, storageKey: true },
        take: BATCH,
      }),
    );

    // 2. Photos of deleted surprises that the immediate cleanup could not remove (storage was down).
    report.deletedSurpriseAssets = await this.drain(() =>
      this.prisma.asset.findMany({
        where: { surprise: { status: SurpriseStatus.DELETED } },
        select: { id: true, storageKey: true },
        take: BATCH,
      }),
    );

    // 3. Finally drop deleted surprises past retention. Their photos are gone (step 2), their
    //    analytics events are detached by the foreign key rather than deleted.
    report.purgedSurprises = (
      await this.prisma.surprise.deleteMany({
        where: { status: SurpriseStatus.DELETED, updatedAt: { lt: cut.deletedSurprises }, assets: { none: {} } },
      })
    ).count;

    report.refreshTokens = (
      await this.prisma.refreshToken.deleteMany({
        where: { OR: [{ expiresAt: { lt: now } }, { revokedAt: { lt: cut.revokedRefreshTokens } }] },
      })
    ).count;

    report.events = (await this.prisma.event.deleteMany({ where: { createdAt: { lt: cut.events } } })).count;

    this.logger.log(`maintenance complete ${JSON.stringify(report)}`);
    return report;
  }

  /**
   * Deletes batches until none are left. Stops if a batch makes no progress (nothing deleted),
   * which would otherwise loop forever on a row that cannot be removed.
   */
  private async drain(findBatch: () => Promise<{ id: string; storageKey: string }[]>): Promise<number> {
    let total = 0;
    for (;;) {
      const batch = await findBatch();
      if (batch.length === 0) return total;
      const deleted = await this.cleanup.deleteAssets(batch);
      total += deleted;
      if (deleted === 0) return total;
    }
  }
}
