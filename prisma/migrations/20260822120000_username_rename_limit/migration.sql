-- Once-a-month username changes.
--
-- Nullable with no default and no backfill: null means "never renamed", so
-- every existing account gets one change available immediately, which is the
-- friendly reading. Their original name was chosen at sign-up, and that is
-- not a rename.

ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "usernameChangedAt" TIMESTAMP(3);
