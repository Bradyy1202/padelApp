import { IsEnum, IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { PozoMode } from '@prisma/client';

export class CreatePozoDto {
  @IsString()
  @Length(2, 80)
  name!: string;

  @IsOptional()
  @IsString()
  clubId?: string;

  @IsEnum(PozoMode)
  mode!: PozoMode;

  @IsInt()
  @Min(1)
  @Max(20)
  courts!: number;

  @IsOptional()
  @IsString()
  scheduledAt?: string;
}
