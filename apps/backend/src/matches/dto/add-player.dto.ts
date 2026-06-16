import { IsIn, IsInt, IsOptional, IsString, Length } from 'class-validator';

/** Añadir un jugador a un partido manualmente (real por id, o invitado por nombre). */
export class AddPlayerDto {
  @IsInt()
  @IsIn([1, 2])
  side!: number;

  @IsOptional()
  @IsString()
  playerId?: string;

  @IsOptional()
  @IsString()
  @Length(2, 60)
  guestName?: string;
}
