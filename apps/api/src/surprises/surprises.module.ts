import { Module } from '@nestjs/common';
import { AssetCleanupModule } from '../assets/asset-cleanup.module';
import { AuthModule } from '../auth/auth.module';
import { TemplatesModule } from '../templates/templates.module';
import { SurprisesController } from './surprises.controller';
import { SurprisesService } from './surprises.service';

@Module({
  imports: [AuthModule, TemplatesModule, AssetCleanupModule],
  controllers: [SurprisesController],
  providers: [SurprisesService],
  exports: [SurprisesService],
})
export class SurprisesModule {}
