import { Module } from '@nestjs/common';
import { MatchesController, MeMatchesController } from './matches.controller';
import { MatchesService } from './matches.service';
import { ScoreValidatorService } from './score-validator.service';
import { QrService } from './qr.service';

@Module({
  controllers: [MatchesController, MeMatchesController],
  providers: [MatchesService, ScoreValidatorService, QrService],
  exports: [MatchesService, ScoreValidatorService],
})
export class MatchesModule {}
