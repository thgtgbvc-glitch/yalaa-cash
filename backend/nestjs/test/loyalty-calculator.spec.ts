import { BadRequestException } from '@nestjs/common';
import { LoyaltyCalculator } from '../src/loyalty/loyalty-calculator';

describe('LoyaltyCalculator', () => {
  it('splits commission and converts the customer share into points', () => {
    const result = LoyaltyCalculator.calculate({
      invoiceAmountSyp: 100000,
      commissionRate: 10,
      pointValueSyp: 5,
    });

    expect(result.commissionAmountSyp).toBe(10000);
    expect(result.customerShareSyp).toBe(5000);
    expect(result.platformRevenueSyp).toBe(5000);
    expect(result.customerPoints).toBe(1000);
  });

  it('rejects invalid invoice amounts', () => {
    expect(() =>
      LoyaltyCalculator.calculate({
        invoiceAmountSyp: 0,
        commissionRate: 6.7,
        pointValueSyp: 5,
      }),
    ).toThrow(BadRequestException);
  });
});
