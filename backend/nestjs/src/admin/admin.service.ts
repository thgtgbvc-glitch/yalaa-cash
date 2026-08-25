import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  CashRequestStatus,
  PointsEntryType,
  Prisma,
  RedemptionStatus,
  SettlementStatus,
  UserRole,
} from "@prisma/client";
import { randomInt } from "crypto";
import { PasswordService } from "../auth/password.service";
import {
  presentBanner,
  presentCashRequest,
  presentCustomer,
  presentDigitalProduct,
  presentGovernorate,
  presentMerchantAccount,
  presentProductRedemption,
  presentStore,
  presentTransaction,
  toNumber,
} from "../common/presenters";
import { FcmService } from "../notifications/fcm.service";
import { PrismaService } from "../prisma/prisma.service";
import {
  AdjustCustomerPointsDto,
  AdminListCashRequestsDto,
  AdminListProductRedemptionsDto,
  CreateBannerDto,
  CreateDigitalProductDto,
  CreateGovernorateDto,
  CreateMerchantAccountDto,
  CreateStoreDto,
  ResolveProductRedemptionDto,
  SendNotificationDto,
  SettleStoreDto,
  SettlementQueryDto,
  UpdateBannerDto,
  UpdateDigitalProductDto,
  UpdateGovernorateDto,
  UpdatePointSettingsDto,
  UpdateStoreDto,
} from "./dto/admin.dto";

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly fcm: FcmService,
  ) {}

  async overview() {
    const [
      customerCount,
      storeCount,
      transactionAggregate,
      pendingCashRequests,
    ] = await Promise.all([
      this.prisma.customerProfile.count(),
      this.prisma.store.count({ where: { isActive: true } }),
      this.prisma.loyaltyTransaction.aggregate({
        _count: { id: true },
        _sum: {
          amountSyp: true,
          platformRevenueSyp: true,
          commissionAmountSyp: true,
        },
      }),
      this.prisma.cashRedemptionRequest.count({
        where: { status: CashRequestStatus.PENDING },
      }),
    ]);

    return {
      customers: customerCount,
      activeStores: storeCount,
      transactions: transactionAggregate._count.id,
      totalSalesSyp: toNumber(transactionAggregate._sum.amountSyp ?? 0n),
      platformRevenueSyp: toNumber(
        transactionAggregate._sum.platformRevenueSyp ?? 0n,
      ),
      commissionDueSyp: toNumber(
        transactionAggregate._sum.commissionAmountSyp ?? 0n,
      ),
      pendingCashRequests,
    };
  }

  async listCustomers() {
    const customers = await this.prisma.customerProfile.findMany({
      include: { user: true },
      orderBy: { createdAt: "desc" },
    });
    return { items: customers.map(presentCustomer) };
  }

  async listRecentTransactions(limit: number) {
    const safeLimit = Math.min(Math.max(Math.trunc(limit) || 8, 1), 50);
    const transactions = await this.prisma.loyaltyTransaction.findMany({
      include: { store: { select: { name: true } } },
      orderBy: { createdAt: "desc" },
      take: safeLimit,
    });
    return { items: transactions.map(presentTransaction) };
  }

  async grantPoints(
    adminUserId: string,
    customerId: string,
    dto: AdjustCustomerPointsDto,
  ) {
    return this.adjustPoints(adminUserId, customerId, dto, dto.points);
  }

  async deductPoints(
    adminUserId: string,
    customerId: string,
    dto: AdjustCustomerPointsDto,
  ) {
    return this.adjustPoints(adminUserId, customerId, dto, -dto.points);
  }

  async deleteCustomer(customerId: string) {
    await this.prisma.user.delete({ where: { id: customerId } });
    return { success: true };
  }

  async listCashRequests(query: AdminListCashRequestsDto) {
    const status = query.status?.toUpperCase() as CashRequestStatus | undefined;
    const requests = await this.prisma.cashRedemptionRequest.findMany({
      where: status ? { status } : undefined,
      include: { customer: { select: { name: true } } },
      orderBy: { createdAt: "desc" },
    });
    return { items: requests.map(presentCashRequest) };
  }

  async resolveCashRequest(
    adminUserId: string,
    requestId: string,
    approve: boolean,
  ) {
    const updated = await this.prisma.$transaction(
      async (tx) => {
        const request = await tx.cashRedemptionRequest.findUnique({
          where: { id: requestId },
        });
        if (!request || request.status !== CashRequestStatus.PENDING) {
          throw new NotFoundException("Pending cash request was not found.");
        }

        if (!approve) {
          const customer = await tx.customerProfile.findUniqueOrThrow({
            where: { userId: request.customerId },
            select: { pointsBalance: true },
          });
          const rejected = await tx.cashRedemptionRequest.update({
            where: { id: request.id },
            data: {
              status: CashRequestStatus.REJECTED,
              settledByUserId: adminUserId,
              settledAt: new Date(),
            },
          });
          await tx.pointsLedgerEntry.create({
            data: {
              customerId: request.customerId,
              entryType: PointsEntryType.CASH_RELEASE,
              pointsDelta: 0,
              balanceAfter: customer.pointsBalance,
              referenceId: request.id,
              note: "Cash redemption request rejected.",
            },
          });
          return rejected;
        }

        const customer = await tx.customerProfile.findUnique({
          where: { userId: request.customerId },
          select: { pointsBalance: true },
        });
        if (!customer) throw new NotFoundException("Customer was not found.");
        if (customer.pointsBalance < request.pointsRequested) {
          throw new BadRequestException(
            "Customer does not have enough points.",
          );
        }

        const savedCustomer = await tx.customerProfile.update({
          where: { userId: request.customerId },
          data: { pointsBalance: { decrement: request.pointsRequested } },
          select: { pointsBalance: true },
        });
        const settled = await tx.cashRedemptionRequest.update({
          where: { id: request.id },
          data: {
            status: CashRequestStatus.SETTLED,
            settledByUserId: adminUserId,
            settledAt: new Date(),
          },
        });
        await tx.pointsLedgerEntry.create({
          data: {
            customerId: request.customerId,
            entryType: PointsEntryType.CASH_SETTLE,
            pointsDelta: -request.pointsRequested,
            balanceAfter: savedCustomer.pointsBalance,
            referenceId: request.id,
            note: "Cash redemption request settled.",
          },
        });
        return settled;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    if (approve) {
      void this.fcm
        .sendToUser(updated.customerId, {
          title: "تمت العملية",
          body: "تم تحويل مبلغ استبدال النقاط بنجاح.",
        })
        .catch(() => undefined);
    }

    return presentCashRequest(updated);
  }

  async listProductRedemptions(query: AdminListProductRedemptionsDto) {
    const status = query.status?.toUpperCase() as
      | RedemptionStatus
      | undefined;
    const items = await this.prisma.productRedemption.findMany({
      where: status ? { status } : undefined,
      include: {
        customer: { select: { name: true, user: { select: { phone: true } } } },
        product: { select: { name: true } },
      },
      orderBy: { createdAt: "desc" },
    });
    return { items: items.map(presentProductRedemption) };
  }

  /**
   * Deducts points exactly once, only here, only on approve — mirrors
   * resolveCashRequest: the status is re-checked inside a Serializable
   * transaction, so a request that already left PENDING (settled or
   * rejected by an earlier call) is rejected as NotFound rather than
   * processed a second time.
   */
  async resolveProductRedemption(
    redemptionId: string,
    dto: ResolveProductRedemptionDto,
  ) {
    const updated = await this.prisma.$transaction(
      async (tx) => {
        const redemption = await tx.productRedemption.findUnique({
          where: { id: redemptionId },
        });
        if (!redemption || redemption.status !== RedemptionStatus.PENDING) {
          throw new NotFoundException(
            "Pending product redemption was not found.",
          );
        }

        if (!dto.approve) {
          const customer = await tx.customerProfile.findUniqueOrThrow({
            where: { userId: redemption.customerId },
            select: { pointsBalance: true },
          });
          const rejected = await tx.productRedemption.update({
            where: { id: redemption.id },
            data: { status: RedemptionStatus.REJECTED },
          });
          await tx.pointsLedgerEntry.create({
            data: {
              customerId: redemption.customerId,
              entryType: PointsEntryType.PRODUCT_RELEASE,
              pointsDelta: 0,
              balanceAfter: customer.pointsBalance,
              referenceId: redemption.id,
              note: "Digital product redemption rejected.",
            },
          });
          return rejected;
        }

        const customer = await tx.customerProfile.findUnique({
          where: { userId: redemption.customerId },
          select: { pointsBalance: true },
        });
        if (!customer) throw new NotFoundException("Customer was not found.");
        if (customer.pointsBalance < redemption.pointsCostSnapshot) {
          throw new BadRequestException(
            "Customer does not have enough points.",
          );
        }

        const savedCustomer = await tx.customerProfile.update({
          where: { userId: redemption.customerId },
          data: { pointsBalance: { decrement: redemption.pointsCostSnapshot } },
          select: { pointsBalance: true },
        });
        const fulfilled = await tx.productRedemption.update({
          where: { id: redemption.id },
          data: { status: RedemptionStatus.FULFILLED, fulfilledAt: new Date() },
        });
        await tx.pointsLedgerEntry.create({
          data: {
            customerId: redemption.customerId,
            entryType: PointsEntryType.PRODUCT_REDEEM,
            pointsDelta: -redemption.pointsCostSnapshot,
            balanceAfter: savedCustomer.pointsBalance,
            referenceId: redemption.id,
            note: "Digital product redemption fulfilled.",
          },
        });
        return fulfilled;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    if (dto.approve) {
      void this.fcm
        .sendToUser(updated.customerId, {
          title: "تمت العملية",
          body: "تم تسليم طلب استبدال المنتج الرقمي بنجاح.",
        })
        .catch(() => undefined);
    }

    return presentProductRedemption(updated);
  }

  async sendGeneralNotification(dto: SendNotificationDto) {
    return this.fcm.sendToAllCustomers({ title: dto.title, body: dto.body });
  }

  async listStores() {
    const stores = await this.prisma.store.findMany({
      orderBy: [{ city: "asc" }, { category: "asc" }, { name: "asc" }],
    });
    return { items: stores.map(presentStore) };
  }

  async listGovernorates() {
    const items = await this.prisma.governorate.findMany({
      orderBy: [{ displayOrder: "asc" }, { nameAr: "asc" }],
    });
    return { items: items.map(presentGovernorate) };
  }

  async listBanners(placement?: string) {
    const items = await this.prisma.banner.findMany({
      where: placement
        ? { placement: placement.toUpperCase() as any }
        : undefined,
      orderBy: [{ displayOrder: "asc" }, { createdAt: "desc" }],
    });
    return { items: items.map(presentBanner) };
  }

  async createBanner(dto: CreateBannerDto) {
    const item = await this.prisma.banner.create({
      data: {
        title: dto.title.trim(),
        subtitle: dto.subtitle?.trim() || null,
        imageUrl: dto.imageUrl.trim(),
        targetUrl: dto.targetUrl?.trim() || null,
        placement: dto.placement ?? "HOME",
        style: dto.style ?? "PROMO",
        isActive: dto.isActive ?? true,
        displayOrder: dto.displayOrder,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        governorateId: dto.governorateId || null,
      },
    });
    return presentBanner(item);
  }

  async updateBanner(bannerId: string, dto: UpdateBannerDto) {
    const current = await this.prisma.banner.findUnique({
      where: { id: bannerId },
    });
    if (!current) throw new NotFoundException("Banner was not found.");

    const item = await this.prisma.banner.update({
      where: { id: bannerId },
      data: {
        ...(dto.title !== undefined ? { title: dto.title.trim() } : {}),
        ...(dto.subtitle !== undefined
          ? { subtitle: dto.subtitle.trim() || null }
          : {}),
        ...(dto.imageUrl !== undefined
          ? { imageUrl: dto.imageUrl.trim() }
          : {}),
        ...(dto.targetUrl !== undefined
          ? { targetUrl: dto.targetUrl.trim() || null }
          : {}),
        ...(dto.placement !== undefined ? { placement: dto.placement } : {}),
        ...(dto.style !== undefined ? { style: dto.style } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.displayOrder !== undefined
          ? { displayOrder: dto.displayOrder }
          : {}),
        ...(dto.startsAt !== undefined
          ? { startsAt: dto.startsAt ? new Date(dto.startsAt) : null }
          : {}),
        ...(dto.endsAt !== undefined
          ? { endsAt: dto.endsAt ? new Date(dto.endsAt) : null }
          : {}),
        ...(dto.governorateId !== undefined
          ? { governorateId: dto.governorateId || null }
          : {}),
      },
    });
    return presentBanner(item);
  }

  async deleteBanner(bannerId: string) {
    const current = await this.prisma.banner.findUnique({
      where: { id: bannerId },
    });
    if (!current) throw new NotFoundException("Banner was not found.");
    await this.prisma.banner.delete({ where: { id: bannerId } });
    return { success: true };
  }

  async createGovernorate(dto: CreateGovernorateDto) {
    const item = await this.prisma.governorate.create({
      data: {
        nameAr: dto.nameAr.trim(),
        isActive: dto.isActive ?? false,
        displayOrder: dto.displayOrder,
      },
    });
    return presentGovernorate(item);
  }

  async updateGovernorate(governorateId: string, dto: UpdateGovernorateDto) {
    const current = await this.prisma.governorate.findUnique({
      where: { id: governorateId },
    });
    if (!current) throw new NotFoundException("Governorate was not found.");
    const item = await this.prisma.governorate.update({
      where: { id: governorateId },
      data: {
        ...(dto.nameAr !== undefined ? { nameAr: dto.nameAr.trim() } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        ...(dto.displayOrder !== undefined
          ? { displayOrder: dto.displayOrder }
          : {}),
      },
    });
    return presentGovernorate(item);
  }

  async createStore(dto: CreateStoreDto) {
    await this.assertExclusiveStoreSlot(dto.city, dto.category);
    const store = await this.prisma.store.create({
      data: {
        name: dto.name.trim(),
        category: dto.category.trim(),
        city: dto.city.trim(),
        commissionRate: new Prisma.Decimal(dto.commissionRate),
        description: dto.description?.trim() ?? "",
        location: dto.location?.trim() ?? "",
        imageUrl: dto.imageUrl?.trim() || null,
        iconSeed: dto.iconSeed ?? 0,
        isActive: dto.isActive ?? true,
      },
    });
    return presentStore(store);
  }

  async updateStore(storeId: string, dto: UpdateStoreDto) {
    const current = await this.prisma.store.findUnique({
      where: { id: storeId },
    });
    if (!current) throw new NotFoundException("Store was not found.");
    const nextCity = dto.city?.trim() ?? current.city;
    const nextCategory = dto.category?.trim() ?? current.category;
    const nextActive = dto.isActive ?? current.isActive;
    if (nextActive)
      await this.assertExclusiveStoreSlot(nextCity, nextCategory, storeId);

    const store = await this.prisma.store.update({
      where: { id: storeId },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.category ? { category: nextCategory } : {}),
        ...(dto.city ? { city: nextCity } : {}),
        ...(dto.commissionRate !== undefined
          ? { commissionRate: new Prisma.Decimal(dto.commissionRate) }
          : {}),
        ...(dto.description !== undefined
          ? { description: dto.description.trim() }
          : {}),
        ...(dto.location !== undefined
          ? { location: dto.location.trim() }
          : {}),
        ...(dto.imageUrl !== undefined
          ? { imageUrl: dto.imageUrl.trim() || null }
          : {}),
        ...(dto.iconSeed !== undefined ? { iconSeed: dto.iconSeed } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
    return presentStore(store);
  }

  async listProducts() {
    const products = await this.prisma.digitalProduct.findMany({
      orderBy: [{ isActive: "desc" }, { costInPoints: "asc" }, { name: "asc" }],
    });
    return { items: products.map(presentDigitalProduct) };
  }

  async createProduct(dto: CreateDigitalProductDto) {
    const product = await this.prisma.digitalProduct.create({
      data: {
        name: dto.name.trim(),
        costInPoints: BigInt(dto.costInPoints),
        imageUrl: dto.imageUrl?.trim() || null,
        iconSeed: dto.iconSeed ?? 0,
        requiresPhoneNumber: dto.requiresPhoneNumber ?? false,
        isActive: dto.isActive ?? true,
      },
    });
    return presentDigitalProduct(product);
  }

  async updateProduct(productId: string, dto: UpdateDigitalProductDto) {
    const product = await this.prisma.digitalProduct.update({
      where: { id: productId },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.costInPoints !== undefined
          ? { costInPoints: BigInt(dto.costInPoints) }
          : {}),
        ...(dto.imageUrl !== undefined
          ? { imageUrl: dto.imageUrl.trim() || null }
          : {}),
        ...(dto.iconSeed !== undefined ? { iconSeed: dto.iconSeed } : {}),
        ...(dto.requiresPhoneNumber !== undefined
          ? { requiresPhoneNumber: dto.requiresPhoneNumber }
          : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });
    return presentDigitalProduct(product);
  }

  async listMerchantAccounts() {
    const accounts = await this.prisma.merchantAccount.findMany({
      include: {
        user: { select: { email: true } },
        store: { select: { name: true } },
        _count: { select: { devices: true } },
      },
      orderBy: { createdAt: "desc" },
    });
    return { items: accounts.map(presentMerchantAccount) };
  }

  async createMerchantAccount(dto: CreateMerchantAccountDto) {
    const password = dto.password ?? this.generatePassword();
    const passwordHash = await this.passwords.hash(password);
    const account = await this.prisma.merchantAccount.create({
      data: {
        displayLabel: dto.displayLabel?.trim() || "Primary account",
        store: { connect: { id: dto.storeId } },
        user: {
          create: {
            role: UserRole.MERCHANT,
            email: dto.email.trim().toLowerCase(),
            passwordHash,
          },
        },
      },
      include: {
        user: { select: { email: true } },
        store: { select: { name: true } },
        _count: { select: { devices: true } },
      },
    });
    return {
      account: presentMerchantAccount(account),
      temporaryPassword: password,
    };
  }

  async getSettings() {
    const settings = await this.prisma.platformSettings.upsert({
      where: { id: 1 },
      update: {},
      create: { id: 1, pointValueSyp: 5 },
    });
    return {
      pointValueSyp: settings.pointValueSyp,
      updatedAt: settings.updatedAt.toISOString(),
    };
  }

  async updateSettings(dto: UpdatePointSettingsDto) {
    const settings = await this.prisma.platformSettings.upsert({
      where: { id: 1 },
      update: { pointValueSyp: dto.pointValueSyp },
      create: { id: 1, pointValueSyp: dto.pointValueSyp },
    });
    return {
      pointValueSyp: settings.pointValueSyp,
      updatedAt: settings.updatedAt.toISOString(),
    };
  }

  async listSettlements(query: SettlementQueryDto) {
    const { periodStart, periodEnd } = this.periodBounds(query);
    const stores = await this.prisma.store.findMany({
      orderBy: { name: "asc" },
    });
    const settlements = await this.prisma.merchantSettlement.findMany({
      where: { periodStart, periodEnd },
    });
    const settlementByStore = new Map(
      settlements.map((item) => [item.storeId, item]),
    );

    const items = await Promise.all(
      stores.map(async (store) => {
        const aggregate = await this.prisma.loyaltyTransaction.aggregate({
          where: {
            storeId: store.id,
            createdAt: { gte: periodStart, lt: periodEnd },
          },
          _count: { id: true },
          _sum: {
            amountSyp: true,
            commissionAmountSyp: true,
          },
        });
        const existing = settlementByStore.get(store.id);
        return {
          id: existing?.id ?? null,
          storeId: store.id,
          storeName: store.name,
          periodStart: periodStart.toISOString(),
          periodEnd: periodEnd.toISOString(),
          transactionCount: aggregate._count.id,
          totalSalesSyp: toNumber(aggregate._sum.amountSyp ?? 0n),
          commissionDueSyp: toNumber(aggregate._sum.commissionAmountSyp ?? 0n),
          status: (existing?.status ?? SettlementStatus.OPEN).toLowerCase(),
          settledAt: existing?.settledAt?.toISOString() ?? null,
        };
      }),
    );

    return { items };
  }

  async settleStore(adminUserId: string, dto: SettleStoreDto) {
    const periodStart = new Date(dto.periodStart);
    const periodEnd = new Date(dto.periodEnd);
    if (
      Number.isNaN(periodStart.getTime()) ||
      Number.isNaN(periodEnd.getTime()) ||
      periodEnd <= periodStart
    ) {
      throw new BadRequestException("Invalid settlement period.");
    }

    const aggregate = await this.prisma.loyaltyTransaction.aggregate({
      where: {
        storeId: dto.storeId,
        createdAt: { gte: periodStart, lt: periodEnd },
      },
      _count: { id: true },
      _sum: {
        amountSyp: true,
        commissionAmountSyp: true,
      },
    });

    const settlement = await this.prisma.merchantSettlement.upsert({
      where: {
        storeId_periodStart_periodEnd: {
          storeId: dto.storeId,
          periodStart,
          periodEnd,
        },
      },
      update: {
        transactionCount: aggregate._count.id,
        totalSalesSyp: aggregate._sum.amountSyp ?? 0n,
        commissionDueSyp: aggregate._sum.commissionAmountSyp ?? 0n,
        status: SettlementStatus.SETTLED,
        settledByUserId: adminUserId,
        settledAt: new Date(),
      },
      create: {
        storeId: dto.storeId,
        periodStart,
        periodEnd,
        transactionCount: aggregate._count.id,
        totalSalesSyp: aggregate._sum.amountSyp ?? 0n,
        commissionDueSyp: aggregate._sum.commissionAmountSyp ?? 0n,
        status: SettlementStatus.SETTLED,
        settledByUserId: adminUserId,
        settledAt: new Date(),
      },
      include: { store: { select: { name: true } } },
    });

    return {
      id: settlement.id,
      storeId: settlement.storeId,
      storeName: settlement.store.name,
      periodStart: settlement.periodStart.toISOString(),
      periodEnd: settlement.periodEnd.toISOString(),
      transactionCount: settlement.transactionCount,
      totalSalesSyp: toNumber(settlement.totalSalesSyp),
      commissionDueSyp: toNumber(settlement.commissionDueSyp),
      status: settlement.status.toLowerCase(),
      settledAt: settlement.settledAt?.toISOString() ?? null,
    };
  }

  private async adjustPoints(
    _adminUserId: string,
    customerId: string,
    dto: AdjustCustomerPointsDto,
    signedPoints: number,
  ) {
    const updated = await this.prisma.$transaction(
      async (tx) => {
        const customer = await tx.customerProfile.findUnique({
          where: { userId: customerId },
          select: { pointsBalance: true },
        });
        if (!customer) throw new NotFoundException("Customer was not found.");
        if (
          signedPoints < 0 &&
          customer.pointsBalance < BigInt(Math.abs(signedPoints))
        ) {
          throw new BadRequestException(
            "Customer does not have enough points.",
          );
        }

        const savedCustomer = await tx.customerProfile.update({
          where: { userId: customerId },
          data: { pointsBalance: { increment: BigInt(signedPoints) } },
          include: { user: true },
        });
        await tx.pointsLedgerEntry.create({
          data: {
            customerId,
            entryType:
              signedPoints >= 0
                ? PointsEntryType.ADMIN_GRANT
                : PointsEntryType.ADMIN_DEDUCT,
            pointsDelta: BigInt(signedPoints),
            balanceAfter: savedCustomer.pointsBalance,
            note: dto.note.trim(),
          },
        });
        return savedCustomer;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    return presentCustomer(updated);
  }

  private async assertExclusiveStoreSlot(
    city: string,
    category: string,
    exceptStoreId?: string,
  ): Promise<void> {
    const existing = await this.prisma.store.findFirst({
      where: {
        city: { equals: city.trim(), mode: "insensitive" },
        category: { equals: category.trim(), mode: "insensitive" },
        isActive: true,
        ...(exceptStoreId ? { id: { not: exceptStoreId } } : {}),
      },
    });
    if (existing) {
      throw new ConflictException(
        "An active exclusive store already exists for this city/category.",
      );
    }
  }

  private periodBounds(query: SettlementQueryDto): {
    periodStart: Date;
    periodEnd: Date;
  } {
    const now = new Date();
    const defaultStart = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1),
    );
    const defaultEnd = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1),
    );
    const periodStart = query.periodStart
      ? new Date(query.periodStart)
      : defaultStart;
    const periodEnd = query.periodEnd ? new Date(query.periodEnd) : defaultEnd;
    if (
      Number.isNaN(periodStart.getTime()) ||
      Number.isNaN(periodEnd.getTime()) ||
      periodEnd <= periodStart
    ) {
      throw new BadRequestException("Invalid settlement period.");
    }
    return { periodStart, periodEnd };
  }

  private generatePassword(): string {
    return randomInt(10000000, 99999999).toString();
  }
}
