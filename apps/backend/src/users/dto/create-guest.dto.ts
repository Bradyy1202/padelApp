import { IsEnum, IsNumber, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { DominantHand, FavSide, Gender } from '@prisma/client';

/** Crear un jugador invitado (placeholder reclamable) — PRD §7.1, §11.1. */
export class CreateGuestDto {
  @IsString()
  @Length(2, 60)
  fullName!: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsEnum(DominantHand)
  dominantHand?: DominantHand;

  @IsOptional()
  @IsEnum(FavSide)
  favSide?: FavSide;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1.0)
  @Max(7.0)
  estLevel?: number;
}
