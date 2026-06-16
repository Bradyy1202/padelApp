import { Module } from '@nestjs/common';
import { MeController, PlayersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [MeController, PlayersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
