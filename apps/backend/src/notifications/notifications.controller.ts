import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';

import { AuthUser, CurrentUser } from '../auth/auth.decorators';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@Controller()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post('devices')
  registerDevice(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    return this.notifications.registerDevice(user.id, dto);
  }

  @Get('me/notifications')
  mine(
    @CurrentUser() user: AuthUser,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.notifications.listMine(
      user.id,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Post('notifications/:id/read')
  read(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.notifications.markRead(user.id, id);
  }
}
