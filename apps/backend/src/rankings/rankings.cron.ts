import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { RankingsService } from './rankings.service';

/**
 * Refresca la vista materializada de ranking (PRD §7.6/§10.8):
 * una vez al arrancar (poblar) y cada 10 minutos.
 */
@Injectable()
export class RankingsCron implements OnApplicationBootstrap {
  private readonly logger = new Logger(RankingsCron.name);

  constructor(private readonly rankings: RankingsService) {}

  async onApplicationBootstrap() {
    await this.safeRefresh();
  }

  @Cron(CronExpression.EVERY_10_MINUTES)
  async scheduled() {
    await this.safeRefresh();
  }

  private async safeRefresh() {
    try {
      await this.rankings.refresh();
      this.logger.log('mv_rankings refrescada');
    } catch (err) {
      this.logger.error(`Fallo al refrescar mv_rankings: ${(err as Error).message}`);
    }
  }
}
