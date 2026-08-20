import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ListStoresDto {
  @IsOptional()
  @IsString()
  @MaxLength(60)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  category?: string;
}
