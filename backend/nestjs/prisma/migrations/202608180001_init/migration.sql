-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('CUSTOMER', 'MERCHANT', 'ADMIN');

-- CreateEnum
CREATE TYPE "AuthMethod" AS ENUM ('PHONE', 'GOOGLE', 'FACEBOOK');

-- CreateEnum
CREATE TYPE "CashRequestStatus" AS ENUM ('PENDING', 'SETTLED', 'REJECTED');

-- CreateEnum
CREATE TYPE "RedemptionStatus" AS ENUM ('PENDING', 'FULFILLED', 'REJECTED');

-- CreateEnum
CREATE TYPE "SettlementStatus" AS ENUM ('OPEN', 'SETTLED');

-- CreateEnum
CREATE TYPE "PointsEntryType" AS ENUM ('INVOICE_EARN', 'CASH_RESERVE', 'CASH_RELEASE', 'CASH_SETTLE', 'PRODUCT_REDEEM', 'ADMIN_GRANT', 'ADMIN_DEDUCT');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "role" "UserRole" NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "passwordHash" TEXT,
    "authMethod" "AuthMethod",
    "oauthProvider" "AuthMethod",
    "oauthSubject" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CustomerProfile" (
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "governorate" TEXT NOT NULL,
    "pointsBalance" BIGINT NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CustomerProfile_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "Store" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "commissionRate" DECIMAL(5,2) NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "location" TEXT NOT NULL DEFAULT '',
    "imageUrl" TEXT,
    "iconSeed" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Store_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantAccount" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "displayLabel" TEXT NOT NULL DEFAULT 'Primary account',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MerchantAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantDevice" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "merchantAccountId" UUID NOT NULL,
    "deviceLabel" TEXT NOT NULL,
    "deviceFingerprintHash" TEXT NOT NULL,
    "lastLoginAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MerchantDevice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminProfile" (
    "userId" UUID NOT NULL,
    "displayName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdminProfile_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "PlatformSettings" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "pointValueSyp" INTEGER NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlatformSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoyaltyTransaction" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "storeId" UUID NOT NULL,
    "customerId" UUID NOT NULL,
    "merchantAccountId" UUID NOT NULL,
    "amountSyp" BIGINT NOT NULL,
    "commissionRateSnapshot" DECIMAL(5,2) NOT NULL,
    "commissionAmountSyp" BIGINT NOT NULL,
    "platformRevenueSyp" BIGINT NOT NULL,
    "customerShareSyp" BIGINT NOT NULL,
    "pointValueSypSnapshot" INTEGER NOT NULL,
    "customerPointsEarned" BIGINT NOT NULL,
    "idempotencyKey" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LoyaltyTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PointsLedgerEntry" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "customerId" UUID NOT NULL,
    "entryType" "PointsEntryType" NOT NULL,
    "pointsDelta" BIGINT NOT NULL,
    "balanceAfter" BIGINT NOT NULL,
    "transactionId" UUID,
    "referenceId" UUID,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PointsLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DigitalProduct" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "costInPoints" BIGINT NOT NULL,
    "imageUrl" TEXT,
    "iconSeed" INTEGER NOT NULL DEFAULT 0,
    "requiresPhoneNumber" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DigitalProduct_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProductRedemption" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "customerId" UUID NOT NULL,
    "productId" UUID NOT NULL,
    "pointsCostSnapshot" BIGINT NOT NULL,
    "phoneNumber" TEXT,
    "status" "RedemptionStatus" NOT NULL DEFAULT 'PENDING',
    "fulfilledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProductRedemption_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CashRedemptionRequest" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "customerId" UUID NOT NULL,
    "pointsRequested" BIGINT NOT NULL,
    "pointValueSypSnapshot" INTEGER NOT NULL,
    "cashValueSyp" BIGINT NOT NULL,
    "status" "CashRequestStatus" NOT NULL DEFAULT 'PENDING',
    "settledByUserId" UUID,
    "settledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CashRedemptionRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantSettlement" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "storeId" UUID NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "transactionCount" INTEGER NOT NULL DEFAULT 0,
    "totalSalesSyp" BIGINT NOT NULL DEFAULT 0,
    "commissionDueSyp" BIGINT NOT NULL DEFAULT 0,
    "status" "SettlementStatus" NOT NULL DEFAULT 'OPEN',
    "settledByUserId" UUID,
    "settledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MerchantSettlement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpChallenge" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE UNIQUE INDEX "User_oauthProvider_oauthSubject_key" ON "User"("oauthProvider", "oauthSubject");

-- CreateIndex
CREATE INDEX "CustomerProfile_governorate_idx" ON "CustomerProfile"("governorate");

-- CreateIndex
CREATE INDEX "Store_city_category_idx" ON "Store"("city", "category");

-- CreateIndex
CREATE INDEX "Store_isActive_idx" ON "Store"("isActive");

-- BusinessRule: one active exclusive store for each city/category pair.
CREATE UNIQUE INDEX "Store_one_active_category_per_city_key"
ON "Store"(lower("city"), lower("category"))
WHERE "isActive" = true;

-- CreateIndex
CREATE UNIQUE INDEX "MerchantAccount_userId_key" ON "MerchantAccount"("userId");

-- CreateIndex
CREATE INDEX "MerchantAccount_storeId_idx" ON "MerchantAccount"("storeId");

-- CreateIndex
CREATE UNIQUE INDEX "MerchantDevice_merchantAccountId_deviceFingerprintHash_key" ON "MerchantDevice"("merchantAccountId", "deviceFingerprintHash");

-- CreateIndex
CREATE UNIQUE INDEX "LoyaltyTransaction_idempotencyKey_key" ON "LoyaltyTransaction"("idempotencyKey");

-- CreateIndex
CREATE INDEX "LoyaltyTransaction_customerId_createdAt_idx" ON "LoyaltyTransaction"("customerId", "createdAt");

-- CreateIndex
CREATE INDEX "LoyaltyTransaction_storeId_createdAt_idx" ON "LoyaltyTransaction"("storeId", "createdAt");

-- CreateIndex
CREATE INDEX "LoyaltyTransaction_merchantAccountId_createdAt_idx" ON "LoyaltyTransaction"("merchantAccountId", "createdAt");

-- CreateIndex
CREATE INDEX "PointsLedgerEntry_customerId_createdAt_idx" ON "PointsLedgerEntry"("customerId", "createdAt");

-- CreateIndex
CREATE INDEX "DigitalProduct_isActive_idx" ON "DigitalProduct"("isActive");

-- CreateIndex
CREATE INDEX "ProductRedemption_customerId_createdAt_idx" ON "ProductRedemption"("customerId", "createdAt");

-- CreateIndex
CREATE INDEX "ProductRedemption_productId_idx" ON "ProductRedemption"("productId");

-- CreateIndex
CREATE INDEX "CashRedemptionRequest_customerId_status_idx" ON "CashRedemptionRequest"("customerId", "status");

-- CreateIndex
CREATE INDEX "CashRedemptionRequest_status_createdAt_idx" ON "CashRedemptionRequest"("status", "createdAt");

-- BusinessRule: a customer cannot have two pending cash requests at once.
CREATE UNIQUE INDEX "CashRedemptionRequest_one_pending_per_customer_key"
ON "CashRedemptionRequest"("customerId")
WHERE "status" = 'PENDING';

-- CreateIndex
CREATE INDEX "MerchantSettlement_periodStart_periodEnd_idx" ON "MerchantSettlement"("periodStart", "periodEnd");

-- CreateIndex
CREATE UNIQUE INDEX "MerchantSettlement_storeId_periodStart_periodEnd_key" ON "MerchantSettlement"("storeId", "periodStart", "periodEnd");

-- CreateIndex
CREATE INDEX "OtpChallenge_phone_createdAt_idx" ON "OtpChallenge"("phone", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- AddForeignKey
ALTER TABLE "CustomerProfile" ADD CONSTRAINT "CustomerProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantAccount" ADD CONSTRAINT "MerchantAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantAccount" ADD CONSTRAINT "MerchantAccount_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantDevice" ADD CONSTRAINT "MerchantDevice_merchantAccountId_fkey" FOREIGN KEY ("merchantAccountId") REFERENCES "MerchantAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdminProfile" ADD CONSTRAINT "AdminProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "CustomerProfile"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_merchantAccountId_fkey" FOREIGN KEY ("merchantAccountId") REFERENCES "MerchantAccount"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PointsLedgerEntry" ADD CONSTRAINT "PointsLedgerEntry_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "CustomerProfile"("userId") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PointsLedgerEntry" ADD CONSTRAINT "PointsLedgerEntry_transactionId_fkey" FOREIGN KEY ("transactionId") REFERENCES "LoyaltyTransaction"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProductRedemption" ADD CONSTRAINT "ProductRedemption_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "CustomerProfile"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProductRedemption" ADD CONSTRAINT "ProductRedemption_productId_fkey" FOREIGN KEY ("productId") REFERENCES "DigitalProduct"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CashRedemptionRequest" ADD CONSTRAINT "CashRedemptionRequest_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "CustomerProfile"("userId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantSettlement" ADD CONSTRAINT "MerchantSettlement_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OtpChallenge" ADD CONSTRAINT "OtpChallenge_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CheckConstraints
ALTER TABLE "CustomerProfile" ADD CONSTRAINT "CustomerProfile_pointsBalance_check" CHECK ("pointsBalance" >= 0);
ALTER TABLE "Store" ADD CONSTRAINT "Store_commissionRate_check" CHECK ("commissionRate" >= 0 AND "commissionRate" <= 100);
ALTER TABLE "PlatformSettings" ADD CONSTRAINT "PlatformSettings_singleton_check" CHECK ("id" = 1 AND "pointValueSyp" > 0);
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_amountSyp_check" CHECK ("amountSyp" > 0);
ALTER TABLE "LoyaltyTransaction" ADD CONSTRAINT "LoyaltyTransaction_commission_split_check" CHECK ("platformRevenueSyp" + "customerShareSyp" = "commissionAmountSyp");
ALTER TABLE "DigitalProduct" ADD CONSTRAINT "DigitalProduct_costInPoints_check" CHECK ("costInPoints" > 0);
ALTER TABLE "CashRedemptionRequest" ADD CONSTRAINT "CashRedemptionRequest_pointsRequested_check" CHECK ("pointsRequested" > 0);
ALTER TABLE "CashRedemptionRequest" ADD CONSTRAINT "CashRedemptionRequest_cashValueSyp_check" CHECK ("cashValueSyp" > 0);
ALTER TABLE "MerchantSettlement" ADD CONSTRAINT "MerchantSettlement_period_check" CHECK ("periodEnd" >= "periodStart");
