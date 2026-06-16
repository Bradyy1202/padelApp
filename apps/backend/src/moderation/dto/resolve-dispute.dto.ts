import { IsEnum } from 'class-validator';

export enum DisputeResolution {
  /** Se mantiene el resultado reportado → CONFIRMED. */
  UPHELD = 'UPHELD',
  /** Se descarta el resultado → DISCARDED. */
  OVERTURNED = 'OVERTURNED',
}

export class ResolveDisputeDto {
  @IsEnum(DisputeResolution)
  resolution!: DisputeResolution;
}
