import {
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";

export class RegisterMerchantDeviceDto {
  @IsString()
  @MinLength(8)
  @MaxLength(256)
  fingerprint!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  label!: string;
}

export class ResolveCustomerQrDto {
  @IsString()
  @MinLength(20)
  payload!: string;
}

export class RegisterInvoiceDto {
  @IsString()
  @MinLength(20)
  customerQrPayload!: string;

  @IsInt()
  @Min(1)
  @Max(9000000000000)
  amountSyp!: number;

  @IsString()
  idempotencyKey!: string;
}

export class MerchantPeriodQueryDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;
}
