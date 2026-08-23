import { BadRequestException } from "@nestjs/common";

export interface LoyaltyCalculationInput {
  invoiceAmountSyp: number;
  commissionRate: number;
  pointValueSyp: number;
}

export interface LoyaltyCalculationResult {
  invoiceAmountSyp: number;
  commissionRate: number;
  commissionAmountSyp: number;
  platformRevenueSyp: number;
  customerShareSyp: number;
  customerPoints: number;
  pointValueSyp: number;
}

export class LoyaltyCalculator {
  static calculate(input: LoyaltyCalculationInput): LoyaltyCalculationResult {
    if (
      !Number.isInteger(input.invoiceAmountSyp) ||
      input.invoiceAmountSyp <= 0
    ) {
      throw new BadRequestException(
        "Invoice amount must be a positive integer.",
      );
    }
    if (input.commissionRate < 0 || input.commissionRate > 100) {
      throw new BadRequestException(
        "Commission rate must be between 0 and 100.",
      );
    }
    if (!Number.isInteger(input.pointValueSyp) || input.pointValueSyp <= 0) {
      throw new BadRequestException("Point value must be a positive integer.");
    }

    const commissionAmountSyp = Math.round(
      (input.invoiceAmountSyp * input.commissionRate) / 100,
    );
    const customerShareSyp = Math.round(commissionAmountSyp / 2);
    const platformRevenueSyp = commissionAmountSyp - customerShareSyp;
    const customerPoints = Math.round(customerShareSyp / input.pointValueSyp);

    return {
      invoiceAmountSyp: input.invoiceAmountSyp,
      commissionRate: input.commissionRate,
      commissionAmountSyp,
      platformRevenueSyp,
      customerShareSyp,
      customerPoints,
      pointValueSyp: input.pointValueSyp,
    };
  }
}
