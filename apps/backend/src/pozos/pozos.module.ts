import { Module } from '@nestjs/common';
import { PozosController } from './pozos.controller';
import { PozosService } from './pozos.service';
import { PozoPairingService } from './pozo-pairing.service';
import { MatchesModule } from '../matches/matches.module';
import { RatingModule } from '../rating/rating.module';

@Module({
  imports: [MatchesModule, RatingModule],
  controllers: [PozosController],
  providers: [PozosService, PozoPairingService],
  exports: [PozosService],
})
export class PozosModule {}
