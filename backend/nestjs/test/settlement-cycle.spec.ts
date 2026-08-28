import { SettlementStatus } from "@prisma/client";
import { AdminService } from "../src/admin/admin.service";
import { MerchantService } from "../src/merchant/merchant.service";

/**
 * Covers the "current accounting cycle resets after settlement" fix:
 * MerchantService.getSummary() and AdminService.listSettlements()/settleStore()
 * must aggregate LoyaltyTransaction rows only from the store's most recent
 * SETTLED settlement's settledAt onward (or its entire history if never
 * settled), instead of a fixed calendar-month window — and every real
 * settlement action must CREATE its own permanent, immutable row rather than
 * being keyed to (and overwriting) a calendar-month upsert slot. This is what
 * allows a store to be settled more than once on the same calendar day, as
 * soon as new transactions exist after the last settlement.
 *
 * PrismaService is replaced with a minimal hand-rolled mock — no real
 * database is touched, matching the existing lightweight test style in this
 * repo (see loyalty-calculator.spec.ts / auth-hashing.spec.ts).
 */

const STORE_ID = "11111111-1111-1111-1111-111111111111";
const USER_ID = "22222222-2222-2222-2222-222222222222";
const ADMIN_ID = "33333333-3333-3333-3333-333333333333";
const STORE_CREATED_AT = new Date("2026-01-01T00:00:00.000Z");

function fakePrisma(overrides: Record<string, unknown> = {}) {
  return {
    merchantAccount: {
      findFirst: jest.fn().mockResolvedValue({ storeId: STORE_ID }),
    },
    merchantSettlement: {
      findFirst: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn(),
    },
    store: {
      findMany: jest
        .fn()
        .mockResolvedValue([{ id: STORE_ID, name: "Test Store" }]),
      findUnique: jest.fn().mockResolvedValue({
        name: "Test Store",
        createdAt: STORE_CREATED_AT,
      }),
    },
    loyaltyTransaction: {
      aggregate: jest.fn(),
    },
    ...overrides,
  };
}

function aggregateResult(count: number, salesSyp: bigint, commissionSyp: bigint) {
  return {
    _count: { id: count },
    _sum: { amountSyp: salesSyp, commissionAmountSyp: commissionSyp },
  };
}

describe("Settlement accounting cycle", () => {
  // A. Transactions before settlement are counted (never-settled store: all history is "current").
  it("A: counts all historical transactions as the current cycle when the store has never been settled", async () => {
    const prisma = fakePrisma();
    prisma.merchantSettlement.findFirst.mockResolvedValue(null);
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(20, 2_000_000n, 100_000n),
    );
    const merchant = new MerchantService(prisma as any, {} as any, {} as any);

    const summary = await merchant.getSummary(USER_ID, {});

    expect(summary.transactionCount).toBe(20);
    expect(summary.totalSalesSyp).toBe(2_000_000);
    expect(summary.commissionDueSyp).toBe(100_000);
    // No prior settlement -> no lower bound on the aggregate.
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, createdAt: undefined },
      }),
    );
  });

  // C. Immediately after settlement, current values are 0/0/0.
  it("C: current summary is 0/0/0 immediately after settlement with no new activity", async () => {
    const prisma = fakePrisma();
    const settledAt = new Date("2026-08-15T12:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValue({
      settledAt,
      status: SettlementStatus.SETTLED,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(0, 0n, 0n),
    );
    const merchant = new MerchantService(prisma as any, {} as any, {} as any);

    const summary = await merchant.getSummary(USER_ID, {});

    expect(summary.transactionCount).toBe(0);
    expect(summary.totalSalesSyp).toBe(0);
    expect(summary.commissionDueSyp).toBe(0);
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, createdAt: { gte: settledAt } },
      }),
    );
  });

  // D. A transaction created AFTER settledAt is counted in the new cycle.
  it("D: a new transaction after settledAt contributes to the new current cycle", async () => {
    const prisma = fakePrisma();
    const settledAt = new Date("2026-08-15T12:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValue({
      settledAt,
      status: SettlementStatus.SETTLED,
    });
    // Simulates one new 100,000 SYP sale (5,000 commission) after settlement.
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(1, 100_000n, 5_000n),
    );
    const merchant = new MerchantService(prisma as any, {} as any, {} as any);

    const summary = await merchant.getSummary(USER_ID, {});

    expect(summary.transactionCount).toBe(1);
    expect(summary.totalSalesSyp).toBe(100_000);
    expect(summary.commissionDueSyp).toBe(5_000);
  });

  // G. Multiple settlements/cycles use the latest successful settlement boundary.
  it("G: with two prior settlements, the cycle boundary is the LATEST settledAt, not the first", async () => {
    const prisma = fakePrisma();
    const latestSettledAt = new Date("2026-09-10T00:00:00.000Z");
    // findFirst with orderBy settledAt desc should return the latest one;
    // the mock simulates that ordering having already been applied by Prisma.
    prisma.merchantSettlement.findFirst.mockResolvedValue({
      settledAt: latestSettledAt,
      status: SettlementStatus.SETTLED,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(3, 300_000n, 15_000n),
    );
    const merchant = new MerchantService(prisma as any, {} as any, {} as any);

    await merchant.getSummary(USER_ID, {});

    expect(prisma.merchantSettlement.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, status: SettlementStatus.SETTLED },
        orderBy: { settledAt: "desc" },
      }),
    );
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, createdAt: { gte: latestSettledAt } },
      }),
    );
  });

  // Explicit-period queries (historical browsing) must keep the original
  // calendar-bounded behavior, unaffected by the current-cycle fix.
  it("preserves explicit-period queries as literal calendar bounds, ignoring settlement history (Merchant)", async () => {
    const prisma = fakePrisma();
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(7, 700_000n, 35_000n),
    );
    const merchant = new MerchantService(prisma as any, {} as any, {} as any);

    await merchant.getSummary(USER_ID, {
      from: "2026-07-01T00:00:00.000Z",
      to: "2026-08-01T00:00:00.000Z",
    });

    // Explicit period must NOT trigger a currentCycleStart() lookup at all.
    expect(prisma.merchantSettlement.findFirst).not.toHaveBeenCalled();
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          storeId: STORE_ID,
          createdAt: {
            gte: new Date("2026-07-01T00:00:00.000Z"),
            lt: new Date("2026-08-01T00:00:00.000Z"),
          },
        },
      }),
    );
  });

  it("Admin listSettlements(): explicit-period queries stay literally calendar-bounded", async () => {
    const prisma = fakePrisma();
    prisma.merchantSettlement.findMany.mockResolvedValue([
      {
        id: "hist-1",
        storeId: STORE_ID,
        status: SettlementStatus.SETTLED,
        settledAt: new Date("2026-07-20T00:00:00.000Z"),
      },
    ]);
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(7, 700_000n, 35_000n),
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const { items } = await admin.listSettlements({
      periodStart: "2026-07-01T00:00:00.000Z",
      periodEnd: "2026-08-01T00:00:00.000Z",
    } as any);

    // Explicit period must NOT trigger a latestSettlement() lookup at all.
    expect(prisma.merchantSettlement.findFirst).not.toHaveBeenCalled();
    expect(items[0].status).toBe("settled");
    expect(items[0].transactionCount).toBe(7);
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          storeId: STORE_ID,
          createdAt: {
            gte: new Date("2026-07-01T00:00:00.000Z"),
            lt: new Date("2026-08-01T00:00:00.000Z"),
          },
        },
      }),
    );
  });

  // ---------------------------------------------------------------------
  // Same-day re-settlement fix: settleStore() always CREATEs a new,
  // permanent row derived from server-side cycle boundaries, and
  // listSettlements()'s default view reports OPEN/SETTLED from the real
  // cycle state instead of a calendar-month-keyed row.
  // ---------------------------------------------------------------------

  // (A) sale -> settlement T1: current due/count becomes zero.
  it("A: settlement at T1 creates the first row and the current cycle becomes 0/0/0", async () => {
    const prisma = fakePrisma();
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(null); // never settled before settleStore()
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(20, 2_000_000n, 100_000n),
    );
    const t1 = new Date("2026-08-15T10:00:00.000Z");
    const created = {
      id: "settlement-1",
      storeId: STORE_ID,
      periodStart: STORE_CREATED_AT,
      periodEnd: t1,
      transactionCount: 20,
      totalSalesSyp: 2_000_000n,
      commissionDueSyp: 100_000n,
      status: SettlementStatus.SETTLED,
      settledByUserId: ADMIN_ID,
      settledAt: t1,
    };
    prisma.merchantSettlement.create.mockResolvedValue(created);
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const result = await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    expect(prisma.merchantSettlement.create).toHaveBeenCalledTimes(1);
    const createArgs = prisma.merchantSettlement.create.mock.calls[0][0];
    // Cycle start derives from the store's own createdAt (never settled
    // before), NOT from the client-supplied periodStart string.
    expect(createArgs.data.periodStart).toEqual(STORE_CREATED_AT);
    expect(createArgs.data.status).toBe(SettlementStatus.SETTLED);
    expect(result.transactionCount).toBe(20);
    expect(result.totalSalesSyp).toBe(2_000_000);
    expect(result.commissionDueSyp).toBe(100_000);
    expect(result.status).toBe("settled");

    // Immediately after: the "current" view must report 0/0/0 and SETTLED.
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(created);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(0, 0n, 0n),
    );
    const { items } = await admin.listSettlements({} as any);
    expect(items[0].transactionCount).toBe(0);
    expect(items[0].totalSalesSyp).toBe(0);
    expect(items[0].commissionDueSyp).toBe(0);
    expect(items[0].status).toBe("settled");
    expect(items[0].id).toBe("settlement-1");
  });

  // (B) sale -> settlement T1 -> NEW sale after T1 on the SAME calendar day:
  // status OPEN, only the new sale counted, second settlement succeeds.
  it("B: a new sale after T1 on the same day reopens the store and only the new sale is counted", async () => {
    const prisma = fakePrisma();
    const t1 = new Date("2026-08-15T10:00:00.000Z");
    const t1Settlement = {
      id: "settlement-1",
      storeId: STORE_ID,
      periodStart: STORE_CREATED_AT,
      periodEnd: t1,
      transactionCount: 20,
      totalSalesSyp: 2_000_000n,
      commissionDueSyp: 100_000n,
      status: SettlementStatus.SETTLED,
      settledAt: t1,
    };

    // listSettlements() right after the NEW sale (same calendar day as T1).
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(t1Settlement);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(1, 50_000n, 2_500n), // exactly one new sale
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const { items } = await admin.listSettlements({} as any);

    expect(items[0].status).toBe("open");
    expect(items[0].transactionCount).toBe(1);
    expect(items[0].totalSalesSyp).toBe(50_000);
    expect(items[0].commissionDueSyp).toBe(2_500);
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, createdAt: { gte: t1 } },
      }),
    );

    // Second settlement, same calendar day, must succeed and create a row.
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(t1Settlement);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(1, 50_000n, 2_500n),
    );
    const t2 = new Date("2026-08-15T18:00:00.000Z"); // later the SAME day
    prisma.merchantSettlement.create.mockResolvedValue({
      id: "settlement-2",
      storeId: STORE_ID,
      periodStart: t1,
      periodEnd: t2,
      transactionCount: 1,
      totalSalesSyp: 50_000n,
      commissionDueSyp: 2_500n,
      status: SettlementStatus.SETTLED,
      settledAt: t2,
    });

    const result = await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    expect(result.status).toBe("settled");
    expect(result.transactionCount).toBe(1);
    expect(result.totalSalesSyp).toBe(50_000);
    const createArgs = prisma.merchantSettlement.create.mock.calls[0][0];
    // The new cycle starts exactly at T1 (the prior settledAt) — never a
    // calendar-day/month boundary.
    expect(createArgs.data.periodStart).toEqual(t1);
  });

  // (C) After T2: two distinct rows exist, T1 is unchanged, T2 has only the
  // second-cycle values, current due/count is zero again.
  it("C: after T2, T1 and T2 are two distinct, independently correct rows", async () => {
    const prisma = fakePrisma();
    const t1 = new Date("2026-08-15T10:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce({
      id: "settlement-1",
      storeId: STORE_ID,
      periodStart: STORE_CREATED_AT,
      periodEnd: t1,
      transactionCount: 20,
      totalSalesSyp: 2_000_000n,
      commissionDueSyp: 100_000n,
      status: SettlementStatus.SETTLED,
      settledAt: t1,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(1, 50_000n, 2_500n),
    );
    const t2Row = {
      id: "settlement-2",
      storeId: STORE_ID,
      periodStart: t1,
      periodEnd: new Date("2026-08-15T18:00:00.000Z"),
      transactionCount: 1,
      totalSalesSyp: 50_000n,
      commissionDueSyp: 2_500n,
      status: SettlementStatus.SETTLED,
      settledAt: new Date("2026-08-15T18:00:00.000Z"),
    };
    prisma.merchantSettlement.create.mockResolvedValue(t2Row);
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const result = await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    // T1 was never touched: create() was the only mutation, no update/upsert
    // exists on the mock at all (would throw if called, proving it can't be).
    expect(prisma.merchantSettlement.create).toHaveBeenCalledTimes(1);
    expect(result.id).toBe("settlement-2");
    expect(result.transactionCount).toBe(1);
    expect(result.totalSalesSyp).toBe(50_000);
    expect(result.commissionDueSyp).toBe(2_500);

    // Current view after T2: 0/0/0 and SETTLED again.
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(t2Row);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(0, 0n, 0n),
    );
    const { items } = await admin.listSettlements({} as any);
    expect(items[0].status).toBe("settled");
    expect(items[0].transactionCount).toBe(0);
    expect(items[0].id).toBe("settlement-2");
  });

  // (D) Settling again with no new transaction: no third row, no historical
  // row modified, no transaction double-counted.
  it("D: settling again with nothing new does not create another row", async () => {
    const prisma = fakePrisma();
    const t2 = new Date("2026-08-15T18:00:00.000Z");
    const t2Row = {
      id: "settlement-2",
      storeId: STORE_ID,
      periodStart: new Date("2026-08-15T10:00:00.000Z"),
      periodEnd: t2,
      transactionCount: 1,
      totalSalesSyp: 50_000n,
      commissionDueSyp: 2_500n,
      status: SettlementStatus.SETTLED,
      settledAt: t2,
    };
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(t2Row);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(0, 0n, 0n), // nothing new since T2
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const result = await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    expect(prisma.merchantSettlement.create).not.toHaveBeenCalled();
    // The existing last settlement is returned unchanged, using the
    // existing response shape — no new/fabricated row.
    expect(result.id).toBe("settlement-2");
    expect(result.transactionCount).toBe(1);
    expect(result.totalSalesSyp).toBe(50_000);
    expect(result.commissionDueSyp).toBe(2_500);
    expect(result.status).toBe("settled");
  });

  it("a store that has never had any transaction is rejected cleanly, never settled as a zero-value row", async () => {
    const prisma = fakePrisma();
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce(null);
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(0, 0n, 0n),
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    await expect(
      admin.settleStore(ADMIN_ID, {
        storeId: STORE_ID,
        periodStart: "ignored-by-server",
        periodEnd: "ignored-by-server",
      } as any),
    ).rejects.toThrow("There are no transactions to settle for this store.");
    expect(prisma.merchantSettlement.create).not.toHaveBeenCalled();
  });

  // (E) Boundary test: a transaction cannot be included in both adjacent
  // cycles. settleStore()'s aggregate must be upper-bounded by the exact
  // `now` it captures, so the NEXT cycle (which starts at that same instant)
  // never re-counts anything already settled.
  it("E: settleStore's aggregate excludes anything at/after the captured settlement instant", async () => {
    const prisma = fakePrisma();
    const t1 = new Date("2026-08-15T10:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValueOnce({
      id: "settlement-1",
      settledAt: t1,
      status: SettlementStatus.SETTLED,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValueOnce(
      aggregateResult(1, 50_000n, 2_500n),
    );
    prisma.merchantSettlement.create.mockResolvedValue({
      id: "settlement-2",
      storeId: STORE_ID,
      periodStart: t1,
      periodEnd: new Date(),
      transactionCount: 1,
      totalSalesSyp: 50_000n,
      commissionDueSyp: 2_500n,
      status: SettlementStatus.SETTLED,
      settledAt: new Date(),
    });
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    const aggregateArgs =
      prisma.loyaltyTransaction.aggregate.mock.calls[0][0];
    // Lower bound is the prior cycle's exact settledAt (T1)...
    expect(aggregateArgs.where.createdAt.gte).toEqual(t1);
    // ...and an upper bound exists and equals what was persisted as this
    // settlement's periodEnd/settledAt, so nothing at/after that instant
    // can be double-counted by the next cycle.
    expect(aggregateArgs.where.createdAt.lt).toBeInstanceOf(Date);
    const createArgs = prisma.merchantSettlement.create.mock.calls[0][0];
    expect(aggregateArgs.where.createdAt.lt).toEqual(createArgs.data.periodEnd);
    expect(createArgs.data.periodEnd).toEqual(createArgs.data.settledAt);
  });

  it("settleStore never issues a delete or update against loyaltyTransaction, and never upserts/updates MerchantSettlement", async () => {
    const prisma = fakePrisma({
      loyaltyTransaction: {
        aggregate: jest
          .fn()
          .mockResolvedValue(aggregateResult(20, 2_000_000n, 100_000n)),
        delete: jest.fn(),
        deleteMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    });
    prisma.merchantSettlement.findFirst.mockResolvedValue(null);
    prisma.merchantSettlement.create.mockResolvedValue({
      id: "settlement-1",
      storeId: STORE_ID,
      periodStart: STORE_CREATED_AT,
      periodEnd: new Date(),
      transactionCount: 20,
      totalSalesSyp: 2_000_000n,
      commissionDueSyp: 100_000n,
      status: SettlementStatus.SETTLED,
      settledAt: new Date(),
    });
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "ignored-by-server",
      periodEnd: "ignored-by-server",
    } as any);

    expect((prisma.loyaltyTransaction as any).delete).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).deleteMany).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).update).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).updateMany).not.toHaveBeenCalled();
    expect((prisma.merchantSettlement as any).upsert).toBeUndefined();
    expect((prisma.merchantSettlement as any).update).toBeUndefined();
  });
});
