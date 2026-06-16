import { IsBoolean, IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';

export enum RankingScope {
  GLOBAL = 'global',
  COUNTRY = 'country',
  CITY = 'city',
  CLUB = 'club',
  GENDER = 'gender',
}

/** Filtros del ranking (PRD §11.3 GET /rankings). */
export class RankingsQueryDto {
  @IsOptional()
  @IsEnum(RankingScope)
  scope?: RankingScope = RankingScope.GLOBAL;

  @IsOptional()
  @IsString()
  value?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  /** Incluir jugadores provisionales (por defecto solo ESTABLISHED, §7.6). */
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  includeProvisional?: boolean = false;
}
