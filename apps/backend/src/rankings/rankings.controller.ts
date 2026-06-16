import { Controller, Get, Param, Query } from '@nestjs/common';

import { RankingsService } from './rankings.service';
import { RankingsQueryDto } from './dto/rankings-query.dto';

/** Rankings y rating de jugadores (PRD §11.3). */
@Controller()
export class RankingsController {
  constructor(private readonly rankings: RankingsService) {}

  @Get('rankings')
  getRankings(@Query() query: RankingsQueryDto) {
    return this.rankings.getRankings(query);
  }

  @Get('players/:id/rating')
  getRating(@Param('id') id: string) {
    return this.rankings.getPlayerRating(id);
  }

  @Get('players/:id/rating/history')
  getHistory(@Param('id') id: string) {
    return this.rankings.getPlayerRatingHistory(id);
  }
}
