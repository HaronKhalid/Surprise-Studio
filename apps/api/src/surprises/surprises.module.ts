import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { SurprisesController } from './surprises.controller';
import { SurprisesService } from './surprises.service';

@Module({
  imports: [AuthModule],
  controllers: [SurprisesController],
  providers: [SurprisesService],
  exports: [SurprisesService],
})
export class SurprisesModule {}
