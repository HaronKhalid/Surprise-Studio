import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { TemplatesModule } from '../templates/templates.module';
import { SurprisesController } from './surprises.controller';
import { SurprisesService } from './surprises.service';

@Module({
  imports: [AuthModule, TemplatesModule],
  controllers: [SurprisesController],
  providers: [SurprisesService],
  exports: [SurprisesService],
})
export class SurprisesModule {}
