import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { Queue } from 'bullmq';

export const RATING_QUEUE = 'rating';

/** Encola trabajos de cálculo de rating (PRD §12.6). */
@Injectable()
export class RatingQueue {
  constructor(@InjectQueue(RATING_QUEUE) private readonly queue: Queue) {}

  /** Recalcula el rating de un partido confirmado (idempotente por jobId). */
  enqueueMatch(matchId: string) {
    return this.queue.add(
      'match',
      { matchId },
      {
        jobId: `match-${matchId}`,
        removeOnComplete: true,
        removeOnFail: false,
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      },
    );
  }

  /** Recalcula desde cero el rating de un jugador (tras merge). */
  enqueueRecompute(playerId: string) {
    return this.queue.add(
      'recompute',
      { playerId },
      { removeOnComplete: true, attempts: 3, backoff: { type: 'exponential', delay: 2000 } },
    );
  }
}
