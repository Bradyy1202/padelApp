import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';

import { AuthUser, CurrentUser } from '../auth/auth.decorators';
import { MatchesService } from './matches.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { JoinMatchDto } from './dto/join-match.dto';
import { AddPlayerDto } from './dto/add-player.dto';
import { RegisterResultDto } from './dto/register-result.dto';

/** Endpoints de partidos y QR (PRD §11.2). */
@Controller('matches')
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateMatchDto) {
    return this.matches.createMatch(user.id, dto);
  }

  @Post('join')
  join(@CurrentUser() user: AuthUser, @Body() dto: JoinMatchDto) {
    return this.matches.join(user.id, dto);
  }

  @Post(':id/qr')
  qr(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.generateQr(user.id, id);
  }

  @Post(':id/players')
  addPlayer(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddPlayerDto,
  ) {
    return this.matches.addPlayer(user.id, id, dto);
  }

  @Post(':id/result')
  result(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: RegisterResultDto,
  ) {
    return this.matches.registerResult(user.id, id, dto);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.matches.getMatch(id);
  }
}

/** Historial de partidos del usuario (PRD §11.2 GET /me/matches). */
@Controller('me/matches')
export class MeMatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Get()
  mine(
    @CurrentUser() user: AuthUser,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.matches.listMine(
      user.id,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }
}
