import { Module } from '@nestjs/common';
import { MeController, PlayersController } from './users.controller';
import { UsersService } from './users.service';
import { RatingModule } from '../rating/rating.module';

@Module({
  imports: [RatingModule],
  controllers: [MeController, PlayersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
