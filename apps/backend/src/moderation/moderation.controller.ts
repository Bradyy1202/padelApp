import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { Role } from '@prisma/client';

import { AuthUser, CurrentUser, Roles } from '../auth/auth.decorators';
import { ModerationService } from './moderation.service';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto';
import { SetRoleDto } from './dto/set-role.dto';

/** Panel administrativo (PRD §11.6). Todo restringido a administrador. */
@Controller('admin')
@Roles(Role.administrador)
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Get('disputes')
  disputes() {
    return this.moderation.listDisputes();
  }

  @Post('disputes/:id/resolve')
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ResolveDisputeDto,
  ) {
    return this.moderation.resolveDispute(user.id, id, dto.resolution);
  }

  @Post('users/:id/role')
  setRole(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: SetRoleDto) {
    return this.moderation.setRole(user.id, id, dto.role);
  }
}
