import { Module } from '@nestjs/common';
import { MatchesController, MeMatchesController } from './matches.controller';
import { MatchesService } from './matches.service';
import { MatchesCron } from './matches.cron';
import { ScoreValidatorService } from './score-validator.service';
import { QrService } from './qr.service';
import { RatingModule } from '../rating/rating.module';

@Module({
  imports: [RatingModule],
  controllers: [MatchesController, MeMatchesController],
  providers: [MatchesService, MatchesCron, ScoreValidatorService, QrService],
  exports: [MatchesService, ScoreValidatorService],
})
export class MatchesModule {}
