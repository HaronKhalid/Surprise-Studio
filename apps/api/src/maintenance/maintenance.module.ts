import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AssetCleanupModule } from '../assets/asset-cleanup.module';
import { validateEnv } from '../config/env.validation';
import { PrismaModule } from '../prisma/prisma.module';
import { StorageModule } from '../storage/storage.module';
import { MaintenanceService } from './maintenance.service';

/** Just what the job needs: no HTTP, no auth, no rate limiting. */
@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }), PrismaModule, StorageModule, AssetCleanupModule],
  providers: [MaintenanceService],
})
export class MaintenanceModule {}
