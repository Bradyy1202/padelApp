import { IsIn, IsInt, IsOptional, IsString } from 'class-validator';

/** Unirse a un partido por token QR o código corto (PRD §6.4, §11.2). */
export class JoinMatchDto {
  @IsOptional()
  @IsString()
  token?: string;

  @IsOptional()
  @IsString()
  shortCode?: string;

  @IsInt()
  @IsIn([1, 2])
  side!: number;
}
