/*
  Warnings:

  - Added the required column `governorateId` to the `Store` table.

  Safety notes:
  - This migration does NOT hardcode any governorate UUID. The existing
    "إدلب" (Idlib) Governorate row is looked up BY NAME at migration-apply
    time via a subquery, so it resolves correctly against whichever
    database this migration runs on (local dev, production, etc.), each of
    which has its own distinct auto-generated Governorate.id values.
  - If no Governorate row named 'إدلب' exists in this database, the
    explicit RAISE EXCEPTION below aborts the migration immediately with a
    clear error instead of silently leaving rows unassigned. As a second,
    redundant safety net, the subsequent `SET NOT NULL` step would also
    fail on its own if any row were left with a NULL governorateId.
  - No existing Store rows are deleted, recreated, or have any other
    column modified. No Customer or Banner data is touched by this
    migration at all.
*/

-- AlterTable: add the column NULLABLE first so existing rows are preserved.
ALTER TABLE "Store" ADD COLUMN "governorateId" UUID;

-- Backfill: assign every existing Store row to the real "إدلب" Governorate
-- row's actual id, resolved dynamically (never hardcoded).
DO $$
DECLARE
  idlib_id UUID;
BEGIN
  SELECT "id" INTO idlib_id FROM "Governorate" WHERE "nameAr" = 'إدلب' LIMIT 1;

  IF idlib_id IS NULL THEN
    RAISE EXCEPTION 'Migration aborted: no Governorate row named ''إدلب'' (Idlib) was found. Existing Store rows cannot be safely assigned a governorate. Create the Idlib Governorate row first, then re-run this migration.';
  END IF;

  UPDATE "Store" SET "governorateId" = idlib_id WHERE "governorateId" IS NULL;
END $$;

-- AlterTable: now that every row has a value, enforce NOT NULL. This step
-- itself fails the whole migration (rolled back) if any row was somehow
-- left unassigned, as a second independent safety check.
ALTER TABLE "Store" ALTER COLUMN "governorateId" SET NOT NULL;

-- CreateIndex
CREATE INDEX "Store_governorateId_isActive_idx" ON "Store"("governorateId", "isActive");

-- AddForeignKey
ALTER TABLE "Store" ADD CONSTRAINT "Store_governorateId_fkey" FOREIGN KEY ("governorateId") REFERENCES "Governorate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
