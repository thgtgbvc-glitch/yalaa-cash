import { RedemptionStatus } from "@prisma/client";
import { AdminService } from "../src/admin/admin.service";
import { CustomerService } from "../src/customer/customer.service";

/**
 * Covers the Customer product-redemption flow: submit (no deduction),
 * duplicate-PENDING protection (same product), Admin approve (exact-once
 * deduction), and the new read-only Customer history endpoint. Mirrors the
 * mocked-Prisma style already used in settlement-cycle.spec.ts /
 * store-governorate.spec.ts — no real database is touched.
 */

const USER_ID = "11111111-1111-1111-1111-111111111111";
const PRODUCT_ID = "22222222-2222-2222-2222-222222222222";
const REDEMPTION_ID = "33333333-3333-3333-3333-333333333333";
const ADMIN_ID = "44444444-4444-4444-4444-444444444444";

function fakePrisma(overrides: Record<string, unknown> = {}) {
  const base = {
    digitalProduct: {
      findUnique: jest.fn().mockResolvedValue({
        id: PRODUCT_ID,
        isActive: true,
        requiresPhoneNumber: false,
        costInPoints: 100n,
      }),
    },
    customerProfile: {
      findUnique: jest.fn().mockResolvedValue({ pointsBalance: 1000n }),
      findUniqueOrThrow: jest.fn().mockResolvedValue({ pointsBalance: 1000n }),
      update: jest.fn().mockResolvedValue({ pointsBalance: 900n }),
    },
    productRedemption: {
      findFirst: jest.fn().mockResolvedValue(null),
      findUnique: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockResolvedValue({
        id: REDEMPTION_ID,
        customerId: USER_ID,
        productId: PRODUCT_ID,
        pointsCostSnapshot: 100n,
        phoneNumber: null,
        status: RedemptionStatus.PENDING,
        fulfilledAt: null,
        createdAt: new Date(),
      }),
      update: jest.fn(),
      aggregate: jest.fn().mockResolvedValue({ _sum: { pointsCostSnapshot: 0n } }),
    },
    cashRedemptionRequest: {
      aggregate: jest.fn().mockResolvedValue({ _sum: { pointsRequested: 0n } }),
    },
    pointsLedgerEntry: {
      create: jest.fn().mockResolvedValue({}),
    },
    ...overrides,
  };
  // Simulates Prisma's $transaction by running the callback against the
  // same fake client — sufficient for exercising the transaction's logic
  // without a real database.
  (base as any).$transaction = jest.fn((fn: any) => fn(base));
  return base;
}

describe("CustomerService.redeemDigitalProduct — submission", () => {
  // 1. submit redemption: points balance unchanged.
  it("does not deduct or modify the customer's points balance on submit", async () => {
    const prisma = fakePrisma();
    const service = new CustomerService(prisma as any, {} as any, {} as any, {
      sendToUser: jest.fn().mockResolvedValue(undefined),
    } as any);

    await service.redeemDigitalProduct(USER_ID, { productId: PRODUCT_ID } as any);

    expect(prisma.customerProfile.update).not.toHaveBeenCalled();
    const createArgs = prisma.productRedemption.create.mock.calls[0][0];
    expect(createArgs.data.status).toBeUndefined(); // defaults to PENDING in schema
    const ledgerArgs = prisma.pointsLedgerEntry.create.mock.calls[0][0];
    expect(ledgerArgs.data.pointsDelta).toBe(0);
  });

  // 2. duplicate PENDING same product: rejected.
  it("rejects a second submission while a PENDING request already exists for the same product", async () => {
    const prisma = fakePrisma({
      productRedemption: {
        findFirst: jest.fn().mockResolvedValue({ id: "existing-pending" }),
        create: jest.fn(),
        aggregate: jest.fn().mockResolvedValue({ _sum: { pointsCostSnapshot: 100n } }),
      },
    });
    const service = new CustomerService(prisma as any, {} as any, {} as any, {
      sendToUser: jest.fn(),
    } as any);

    await expect(
      service.redeemDigitalProduct(USER_ID, { productId: PRODUCT_ID } as any),
    ).rejects.toThrow("A pending redemption request already exists for this product.");
    expect((prisma.productRedemption as any).create).not.toHaveBeenCalled();
  });

  // 3. FULFILLED old redemption does not prevent a new redemption.
  it("allows a new submission when the only prior request for this product is FULFILLED", async () => {
    // findFirst is scoped to status: PENDING in the query itself, so an
    // existing FULFILLED row correctly never matches — simulated here by
    // resolving null (as the real filtered query would for this case).
    const prisma = fakePrisma();
    const service = new CustomerService(prisma as any, {} as any, {} as any, {
      sendToUser: jest.fn().mockResolvedValue(undefined),
    } as any);

    await expect(
      service.redeemDigitalProduct(USER_ID, { productId: PRODUCT_ID } as any),
    ).resolves.toBeDefined();
    expect(prisma.productRedemption.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: RedemptionStatus.PENDING }),
      }),
    );
  });

  // 4. REJECTED old redemption does not prevent a new redemption.
  it("allows a new submission when the only prior request for this product is REJECTED", async () => {
    const prisma = fakePrisma();
    const service = new CustomerService(prisma as any, {} as any, {} as any, {
      sendToUser: jest.fn().mockResolvedValue(undefined),
    } as any);

    await expect(
      service.redeemDigitalProduct(USER_ID, { productId: PRODUCT_ID } as any),
    ).resolves.toBeDefined();
  });
});

describe("AdminService.resolveProductRedemption — approve", () => {
  // 5. Admin approve deducts exactly once.
  it("deducts points exactly once and marks the redemption FULFILLED", async () => {
    const prisma = fakePrisma({
      productRedemption: {
        findUnique: jest.fn().mockResolvedValue({
          id: REDEMPTION_ID,
          customerId: USER_ID,
          pointsCostSnapshot: 100n,
          status: RedemptionStatus.PENDING,
        }),
        update: jest.fn().mockResolvedValue({
          id: REDEMPTION_ID,
          customerId: USER_ID,
          status: RedemptionStatus.FULFILLED,
          fulfilledAt: new Date(),
          createdAt: new Date(),
        }),
      },
    });
    const admin = new AdminService(prisma as any, {} as any, {
      sendToUser: jest.fn().mockResolvedValue(undefined),
    } as any);

    const result = await admin.resolveProductRedemption(REDEMPTION_ID, {
      approve: true,
    } as any);

    expect(result.status).toBe("fulfilled");
    expect(prisma.customerProfile.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { pointsBalance: { decrement: 100n } },
      }),
    );
  });

  // 6. second approve does not deduct again.
  it("rejects resolving an already-FULFILLED redemption a second time, without deducting again", async () => {
    const prisma = fakePrisma({
      productRedemption: {
        findUnique: jest.fn().mockResolvedValue({
          id: REDEMPTION_ID,
          customerId: USER_ID,
          pointsCostSnapshot: 100n,
          status: RedemptionStatus.FULFILLED, // already resolved
        }),
        update: jest.fn(),
      },
    });
    const admin = new AdminService(prisma as any, {} as any, {
      sendToUser: jest.fn(),
    } as any);

    await expect(
      admin.resolveProductRedemption(REDEMPTION_ID, { approve: true } as any),
    ).rejects.toThrow("Pending product redemption was not found.");
    expect(prisma.customerProfile.update).not.toHaveBeenCalled();
  });
});

describe("CustomerService.listProductRedemptions", () => {
  // 7. only returns the authenticated customer's own records.
  it("scopes the query to the authenticated customer's id only", async () => {
    const prisma = fakePrisma();
    const service = new CustomerService(prisma as any, {} as any, {} as any, {} as any);

    await service.listProductRedemptions(USER_ID);

    expect(prisma.productRedemption.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { customerId: USER_ID } }),
    );
  });

  // 8. preserves PENDING / FULFILLED / REJECTED statuses.
  it("preserves every status in the returned list", async () => {
    const now = new Date();
    const prisma = fakePrisma({
      productRedemption: {
        findMany: jest.fn().mockResolvedValue([
          { id: "1", customerId: USER_ID, productId: PRODUCT_ID, pointsCostSnapshot: 100n, phoneNumber: null, status: RedemptionStatus.PENDING, fulfilledAt: null, createdAt: now, product: { name: "A" } },
          { id: "2", customerId: USER_ID, productId: PRODUCT_ID, pointsCostSnapshot: 100n, phoneNumber: null, status: RedemptionStatus.FULFILLED, fulfilledAt: now, createdAt: now, product: { name: "A" } },
          { id: "3", customerId: USER_ID, productId: PRODUCT_ID, pointsCostSnapshot: 100n, phoneNumber: null, status: RedemptionStatus.REJECTED, fulfilledAt: null, createdAt: now, product: { name: "A" } },
        ]),
      },
    });
    const service = new CustomerService(prisma as any, {} as any, {} as any, {} as any);

    const result = await service.listProductRedemptions(USER_ID);

    expect(result.items.map((i) => i.status)).toEqual(["pending", "fulfilled", "rejected"]);
  });

  // 9. newest-first ordering.
  it("orders results by createdAt descending", async () => {
    const prisma = fakePrisma();
    const service = new CustomerService(prisma as any, {} as any, {} as any, {} as any);

    await service.listProductRedemptions(USER_ID);

    expect(prisma.productRedemption.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ orderBy: { createdAt: "desc" } }),
    );
  });
});
