import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';

import { RATING_QUEUE } from './rating.queue';
import { RatingService } from './rating.service';

/** Worker en proceso que consume la cola de rating (BullMQ sobre Redis). */
@Processor(RATING_QUEUE)
export class RatingProcessor extends WorkerHost {
  private readonly logger = new Logger(RatingProcessor.name);

  constructor(private readonly rating: RatingService) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name === 'match') {
      await this.rating.applyMatch(job.data.matchId);
    } else if (job.name === 'recompute') {
      await this.rating.recomputePlayer(job.data.playerId);
    } else {
      this.logger.warn(`Job desconocido: ${job.name}`);
    }
  }
}
