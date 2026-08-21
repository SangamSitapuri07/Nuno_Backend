-- Google sign-in + public player UID.
--
-- Ordering matters here. `uid` is NOT NULL UNIQUE, so it cannot simply be
-- added to a table that already has rows: every existing account needs a
-- distinct value first. The column is therefore added nullable, backfilled,
-- and only then constrained.

-- ── 1. Password becomes optional ──────────────────────────────
-- Google accounts have no password of their own.
ALTER TABLE "User" ALTER COLUMN "passwordHash" DROP NOT NULL;

-- ── 2. New columns ────────────────────────────────────────────
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "googleId" TEXT;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "usernameSet" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "uid" VARCHAR(10);

-- Everyone who already exists picked their own username at registration.
UPDATE "User" SET "usernameSet" = true WHERE "usernameSet" = false;

-- ── 3. Backfill a unique 10-digit uid for existing rows ───────
-- Loops until it finds a free number, so a collision cannot abort the
-- migration. The range excludes leading zeros.
DO $$
DECLARE
  r RECORD;
  candidate VARCHAR(10);
BEGIN
  FOR r IN SELECT "id" FROM "User" WHERE "uid" IS NULL LOOP
    LOOP
      candidate := (1000000000 + floor(random() * 8999999999))::bigint::text;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM "User" WHERE "uid" = candidate);
    END LOOP;
    UPDATE "User" SET "uid" = candidate WHERE "id" = r."id";
  END LOOP;
END $$;

-- ── 4. Now the constraints can be applied ─────────────────────
ALTER TABLE "User" ALTER COLUMN "uid" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "User_uid_key" ON "User"("uid");
CREATE UNIQUE INDEX IF NOT EXISTS "User_googleId_key" ON "User"("googleId");
CREATE INDEX IF NOT EXISTS "User_uid_idx" ON "User"("uid");
CREATE INDEX IF NOT EXISTS "User_googleId_idx" ON "User"("googleId");
