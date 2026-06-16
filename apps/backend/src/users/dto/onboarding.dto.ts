import {
  IsEnum,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';
import { DominantHand, FavSide, Gender } from '@prisma/client';

/** Datos de onboarding: crea el `player` vinculado al usuario (PRD §6.1, §7.1). */
export class OnboardingDto {
  @IsString()
  @Length(2, 60)
  fullName!: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  clubId?: string;

  @IsOptional()
  @IsEnum(DominantHand)
  dominantHand?: DominantHand;

  @IsOptional()
  @IsEnum(FavSide)
  favSide?: FavSide;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  /** Fecha ISO (YYYY-MM-DD). La edad mínima (≥12) se valida en el servicio. */
  @IsOptional()
  @IsISO8601()
  birthdate?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1.0)
  @Max(7.0)
  estLevel?: number;
}
