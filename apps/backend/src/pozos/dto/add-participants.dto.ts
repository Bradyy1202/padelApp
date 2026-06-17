import { IsArray, IsOptional, IsString } from 'class-validator';

/** Añadir participantes: jugadores existentes por id y/o invitados por nombre. */
export class AddParticipantsDto {
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  playerIds?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  guestNames?: string[];
}
