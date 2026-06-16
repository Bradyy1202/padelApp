import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { Glicko2Service } from './glicko2.service';
import { RatingService } from './rating.service';
import { RatingProcessor } from './rating.processor';
import { RatingQueue, RATING_QUEUE } from './rating.queue';

@Module({
  imports: [BullModule.registerQueue({ name: RATING_QUEUE })],
  providers: [Glicko2Service, RatingService, RatingProcessor, RatingQueue],
  exports: [RatingQueue, RatingService, Glicko2Service],
})
export class RatingModule {}
