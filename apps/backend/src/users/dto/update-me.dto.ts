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

/** Edición de perfil (PRD §11.1 PATCH /me): todos los campos opcionales. */
export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @Length(2, 60)
  fullName?: string;

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

  @IsOptional()
  @IsISO8601()
  birthdate?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1.0)
  @Max(7.0)
  estLevel?: number;
}
