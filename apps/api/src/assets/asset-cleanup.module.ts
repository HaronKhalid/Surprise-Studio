import { Module } from '@nestjs/common';
import { AssetCleanupService } from './asset-cleanup.service';

/** Separate from AssetsModule so Auth and Surprises can use it without a module cycle. */
@Module({ providers: [AssetCleanupService], exports: [AssetCleanupService] })
export class AssetCleanupModule {}
