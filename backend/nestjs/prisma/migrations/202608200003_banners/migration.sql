CREATE TYPE "BannerPlacement" AS ENUM ('HOME');

CREATE TYPE "BannerStyle" AS ENUM ('PROMO', 'FEATURE', 'HIGHLIGHT');

CREATE TABLE "Banner" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" TEXT NOT NULL,
    "subtitle" TEXT,
    "imageUrl" TEXT NOT NULL,
    "targetUrl" TEXT,
    "placement" "BannerPlacement" NOT NULL DEFAULT 'HOME',
    "style" "BannerStyle" NOT NULL DEFAULT 'PROMO',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "governorateId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Banner_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "Banner_placement_isActive_displayOrder_idx" ON "Banner"("placement", "isActive", "displayOrder");
CREATE INDEX "Banner_governorateId_placement_isActive_idx" ON "Banner"("governorateId", "placement", "isActive");

ALTER TABLE "Banner" ADD CONSTRAINT "Banner_governorateId_fkey"
  FOREIGN KEY ("governorateId") REFERENCES "Governorate"("id") ON DELETE SET NULL ON UPDATE CASCADE;
