import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { Role } from '@prisma/client';

import { AuthUser, CurrentUser, Roles } from '../auth/auth.decorators';
import { PozosService } from './pozos.service';
import { CreatePozoDto } from './dto/create-pozo.dto';
import { AddParticipantsDto } from './dto/add-participants.dto';
import { RoundResultsDto } from './dto/round-results.dto';

/** Pozos (PRD §11.4). Mutaciones solo administrador (+ propiedad del pozo). */
@Controller('pozos')
export class PozosController {
  constructor(private readonly pozos: PozosService) {}

  @Post()
  @Roles(Role.administrador)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePozoDto) {
    return this.pozos.create(user.id, dto);
  }

  @Post(':id/participants')
  @Roles(Role.administrador)
  addParticipants(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddParticipantsDto,
  ) {
    return this.pozos.addParticipants(user.id, id, dto);
  }

  @Post(':id/start')
  @Roles(Role.administrador)
  start(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.pozos.start(user.id, id);
  }

  @Post(':id/next-round')
  @Roles(Role.administrador)
  nextRound(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.pozos.nextRound(user.id, id);
  }

  @Post(':id/rounds/:n/results')
  @Roles(Role.administrador)
  results(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('n', ParseIntPipe) n: number,
    @Body() dto: RoundResultsDto,
  ) {
    return this.pozos.submitRoundResults(user.id, id, n, dto);
  }

  @Post(':id/close')
  @Roles(Role.administrador)
  close(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.pozos.close(user.id, id);
  }

  @Get()
  mine(@CurrentUser() user: AuthUser) {
    return this.pozos.listMine(user.id);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.pozos.getPozo(id);
  }

  @Get(':id/standings')
  standings(@Param('id') id: string) {
    return this.pozos.getStandings(id);
  }
}
