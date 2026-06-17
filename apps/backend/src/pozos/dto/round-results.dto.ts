import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsString, ValidateNested } from 'class-validator';
import { SetScoreDto } from '../../matches/dto/register-result.dto';

export class PozoMatchResultDto {
  @IsString()
  pozoMatchId!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SetScoreDto)
  sets!: SetScoreDto[];
}

export class RoundResultsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PozoMatchResultDto)
  results!: PozoMatchResultDto[];
}
