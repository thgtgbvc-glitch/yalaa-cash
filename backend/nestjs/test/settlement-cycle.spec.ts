import { SettlementStatus } from "@prisma/client";
import { AdminService } from "../src/admin/admin.service";
import { MerchantService } from "../src/merchant/merchant.service";

/**
 * Covers the "current accounting cycle resets after settlement" fix:
 * MerchantService.getSummary() and AdminService.listSettlements()/settleStore()
 * must aggregate LoyaltyTransaction rows only from the store's most recent
 * SETTLED settlement's settledAt onward (or its entire history if never
 * settled), instead of a fixed calendar-month window.
 *
 * PrismaService is replaced with a minimal hand-rolled mock — no real
 * database is touched, matching the existing lightweight test style in this
 * repo (see loyalty-calculator.spec.ts / auth-hashing.spec.ts).
 */

const STORE_ID = "11111111-1111-1111-1111-111111111111";
const USER_ID = "22222222-2222-2222-2222-222222222222";
const ADMIN_ID = "33333333-3333-3333-3333-333333333333";

function fakePrisma(overrides: Record<string, unknown> = {}) {
  return {
    merchantAccount: {
      findFirst: jest.fn().mockResolvedValue({ storeId: STORE_ID }),
    },
    merchantSettlement: {
      findFirst: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      upsert: jest.fn(),
    },
    store: {
      findMany: jest.fn().mockResolvedValue([{ id: STORE_ID, name: "Test Store" }]),
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

  // B. settleStore snapshots the correct pre-settlement values.
  it("B: settleStore snapshots exactly the pre-settlement aggregate into MerchantSettlement", async () => {
    const prisma = fakePrisma();
    prisma.merchantSettlement.findFirst.mockResolvedValue(null); // never settled before
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(20, 2_000_000n, 100_000n),
    );
    prisma.merchantSettlement.upsert.mockImplementation(({ update }: any) =>
      Promise.resolve({
        id: "settlement-1",
        storeId: STORE_ID,
        periodStart: new Date("2026-08-01T00:00:00.000Z"),
        periodEnd: new Date("2026-09-01T00:00:00.000Z"),
        ...update,
        store: { name: "Test Store" },
      }),
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const result = await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "2026-08-01T00:00:00.000Z",
      periodEnd: "2026-09-01T00:00:00.000Z",
    } as any);

    expect(result.transactionCount).toBe(20);
    expect(result.totalSalesSyp).toBe(2_000_000);
    expect(result.commissionDueSyp).toBe(100_000);
    expect(result.status).toBe("settled");
    const upsertArgs = prisma.merchantSettlement.upsert.mock.calls[0][0];
    expect(upsertArgs.update.transactionCount).toBe(20);
    expect(upsertArgs.update.totalSalesSyp).toBe(2_000_000n);
    expect(upsertArgs.update.commissionDueSyp).toBe(100_000n);
    expect(upsertArgs.update.status).toBe(SettlementStatus.SETTLED);
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

  // E. Historical transactions remain in the database (settlement never deletes/mutates them).
  it("E: settleStore never issues a delete or update against loyaltyTransaction", async () => {
    const prisma = fakePrisma({
      loyaltyTransaction: {
        aggregate: jest.fn().mockResolvedValue(aggregateResult(20, 2_000_000n, 100_000n)),
        delete: jest.fn(),
        deleteMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    });
    prisma.merchantSettlement.findFirst.mockResolvedValue(null);
    prisma.merchantSettlement.upsert.mockResolvedValue({
      id: "settlement-1",
      storeId: STORE_ID,
      periodStart: new Date("2026-08-01T00:00:00.000Z"),
      periodEnd: new Date("2026-09-01T00:00:00.000Z"),
      transactionCount: 20,
      totalSalesSyp: 2_000_000n,
      commissionDueSyp: 100_000n,
      status: SettlementStatus.SETTLED,
      settledAt: new Date(),
      store: { name: "Test Store" },
    });
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "2026-08-01T00:00:00.000Z",
      periodEnd: "2026-09-01T00:00:00.000Z",
    } as any);

    expect((prisma.loyaltyTransaction as any).delete).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).deleteMany).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).update).not.toHaveBeenCalled();
    expect((prisma.loyaltyTransaction as any).updateMany).not.toHaveBeenCalled();
  });

  // F. Historical MerchantSettlement snapshot remains unchanged (a later settlement
  //    for a NEW period must not touch a prior SETTLED row's stored values).
  it("F: a later settlement upserts a different (storeId, periodStart, periodEnd) row, leaving the earlier settled row untouched", async () => {
    const prisma = fakePrisma();
    const secondSettledAt = new Date("2026-08-15T12:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValue({
      settledAt: secondSettledAt,
      status: SettlementStatus.SETTLED,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(1, 100_000n, 5_000n),
    );
    prisma.merchantSettlement.upsert.mockResolvedValue({
      id: "settlement-2",
      storeId: STORE_ID,
      periodStart: new Date("2026-09-01T00:00:00.000Z"),
      periodEnd: new Date("2026-10-01T00:00:00.000Z"),
      transactionCount: 1,
      totalSalesSyp: 100_000n,
      commissionDueSyp: 5_000n,
      status: SettlementStatus.SETTLED,
      settledAt: new Date(),
      store: { name: "Test Store" },
    });
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    await admin.settleStore(ADMIN_ID, {
      storeId: STORE_ID,
      periodStart: "2026-09-01T00:00:00.000Z",
      periodEnd: "2026-10-01T00:00:00.000Z",
    } as any);

    // The upsert's unique key targets the SECOND period only — Prisma's
    // upsert-by-unique-key semantics guarantee the first (August) row, filed
    // under a different key, is never touched by this call.
    const upsertArgs = prisma.merchantSettlement.upsert.mock.calls[0][0];
    expect(upsertArgs.where.storeId_periodStart_periodEnd.periodStart).toEqual(
      new Date("2026-09-01T00:00:00.000Z"),
    );
    expect(upsertArgs.where.storeId_periodStart_periodEnd.periodEnd).toEqual(
      new Date("2026-10-01T00:00:00.000Z"),
    );
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
  it("preserves explicit-period queries as literal calendar bounds, ignoring settlement history", async () => {
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

  // Admin's listSettlements() must use the SAME cycle boundary as Merchant's
  // getSummary() for the default (current) view.
  it("Admin listSettlements(): current view resets to 0/0/0 right after settlement, matching Merchant's summary", async () => {
    const prisma = fakePrisma();
    const settledAt = new Date("2026-08-15T12:00:00.000Z");
    prisma.merchantSettlement.findFirst.mockResolvedValue({
      settledAt,
      status: SettlementStatus.SETTLED,
    });
    prisma.loyaltyTransaction.aggregate.mockResolvedValue(
      aggregateResult(0, 0n, 0n),
    );
    const admin = new AdminService(prisma as any, {} as any, {} as any);

    const { items } = await admin.listSettlements({} as any);

    expect(items).toHaveLength(1);
    expect(items[0].transactionCount).toBe(0);
    expect(items[0].totalSalesSyp).toBe(0);
    expect(items[0].commissionDueSyp).toBe(0);
    expect(prisma.loyaltyTransaction.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { storeId: STORE_ID, createdAt: { gte: settledAt } },
      }),
    );
  });
});
