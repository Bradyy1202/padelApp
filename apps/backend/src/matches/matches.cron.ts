import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { MatchesService } from './matches.service';

/** Descarta cada minuto los partidos pendientes vencidos (ventana 24h, PRD §7.4). */
@Injectable()
export class MatchesCron {
  private readonly logger = new Logger(MatchesCron.name);

  constructor(private readonly matches: MatchesService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async discardExpired() {
    const n = await this.matches.discardExpired();
    if (n > 0) this.logger.log(`Descartados ${n} partidos vencidos`);
  }
}
