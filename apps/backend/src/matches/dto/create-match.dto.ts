import { IsEnum, IsIn, IsOptional, IsInt } from 'class-validator';

export enum CreatableMatchType {
  FRIENDLY = 'FRIENDLY',
  COMPETITIVE = 'COMPETITIVE',
}

/** Crear un partido (PRD §6.3, §11.2 POST /matches). */
export class CreateMatchDto {
  @IsEnum(CreatableMatchType)
  type!: CreatableMatchType;

  @IsOptional()
  @IsInt()
  @IsIn([1, 3])
  bestOf?: number;
}
