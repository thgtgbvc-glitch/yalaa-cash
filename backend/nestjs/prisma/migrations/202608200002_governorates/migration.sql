CREATE TABLE "Governorate" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "nameAr" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Governorate_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "CustomerProfile" ADD COLUMN "governorateId" UUID;

CREATE UNIQUE INDEX "Governorate_nameAr_key" ON "Governorate"("nameAr");
CREATE INDEX "Governorate_isActive_displayOrder_idx" ON "Governorate"("isActive", "displayOrder");
CREATE INDEX "CustomerProfile_governorateId_idx" ON "CustomerProfile"("governorateId");

ALTER TABLE "CustomerProfile" ADD CONSTRAINT "CustomerProfile_governorateId_fkey"
  FOREIGN KEY ("governorateId") REFERENCES "Governorate"("id") ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO "Governorate" ("id", "nameAr", "isActive", "displayOrder", "updatedAt")
VALUES ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'إدلب', true, 1, CURRENT_TIMESTAMP)
ON CONFLICT ("nameAr") DO UPDATE SET "isActive" = true, "displayOrder" = 1, "updatedAt" = CURRENT_TIMESTAMP;
