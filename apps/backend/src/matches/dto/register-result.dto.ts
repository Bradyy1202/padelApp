import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsInt, IsOptional, Min, ValidateNested } from 'class-validator';

export class SetScoreDto {
  @IsInt()
  @Min(0)
  games1!: number;

  @IsInt()
  @Min(0)
  games2!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  tiebreak1?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  tiebreak2?: number;
}

/** Registrar el resultado de un partido (PRD §6.5, §11.2). */
export class RegisterResultDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SetScoreDto)
  sets!: SetScoreDto[];
}
