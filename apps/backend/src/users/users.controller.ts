import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { CurrentUser, AuthUser } from '../auth/auth.decorators';
import { UsersService } from './users.service';
import { OnboardingDto } from './dto/onboarding.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { CreateGuestDto } from './dto/create-guest.dto';

/** Endpoints del usuario autenticado (PRD §11.1, prefijo /me). */
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  getMe(@CurrentUser() user: AuthUser) {
    return this.users.getMe(user.id);
  }

  @Post('onboarding')
  onboarding(@CurrentUser() user: AuthUser, @Body() dto: OnboardingDto) {
    return this.users.completeOnboarding(user.id, dto);
  }

  @Patch()
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(user.id, dto);
  }

  @Post('photo')
  @UseInterceptors(FileInterceptor('file'))
  uploadPhoto(@CurrentUser() user: AuthUser, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('Falta el archivo "file"');
    return this.users.uploadPhoto(user.id, file.buffer, file.mimetype);
  }

  @Delete()
  deleteAccount(@CurrentUser() user: AuthUser) {
    return this.users.deleteAccount(user.id);
  }
}

/** Endpoints de jugadores y gestión de invitados (PRD §11.1, prefijo /players). */
@Controller('players')
export class PlayersController {
  constructor(private readonly users: UsersService) {}

  // Rutas específicas antes de ':id' para que no las capture el parámetro.
  @Get('guest/suggestions')
  suggestions(@CurrentUser() user: AuthUser, @Query('name') name?: string) {
    return this.users.guestSuggestions(user.id, name);
  }

  @Post('guest')
  createGuest(@CurrentUser() user: AuthUser, @Body() dto: CreateGuestDto) {
    return this.users.createGuest(user.id, dto);
  }

  @Get(':id')
  getPlayer(@Param('id') id: string) {
    return this.users.getPlayer(id);
  }

  @Post(':guestId/claim')
  claim(@CurrentUser() user: AuthUser, @Param('guestId') guestId: string) {
    return this.users.claimGuest(user.id, guestId);
  }
}
