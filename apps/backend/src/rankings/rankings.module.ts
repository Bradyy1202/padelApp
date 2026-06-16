import { Module } from '@nestjs/common';
import { RankingsController } from './rankings.controller';
import { RankingsService } from './rankings.service';
import { RankingsCron } from './rankings.cron';

@Module({
  controllers: [RankingsController],
  providers: [RankingsService, RankingsCron],
  exports: [RankingsService],
})
export class RankingsModule {}
