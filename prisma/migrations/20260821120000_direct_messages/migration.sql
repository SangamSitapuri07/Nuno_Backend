-- Persisted one-to-one messages.
--
-- DMs were relayed over the socket and never stored, so a conversation only
-- existed in the two apps' memory and anything sent to an offline friend was
-- dropped. This is a plain append-only table; `readAt` drives the unread
-- badge on the friends list.

CREATE TABLE IF NOT EXISTS "DirectMessage" (
  "id"         TEXT NOT NULL,
  "senderId"   TEXT NOT NULL,
  "receiverId" TEXT NOT NULL,
  "body"       VARCHAR(500) NOT NULL,
  "readAt"     TIMESTAMP(3),
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "DirectMessage_pkey" PRIMARY KEY ("id")
);

-- Reading one conversation needs both directions, newest first.
CREATE INDEX IF NOT EXISTS "DirectMessage_senderId_receiverId_createdAt_idx"
  ON "DirectMessage"("senderId", "receiverId", "createdAt");

CREATE INDEX IF NOT EXISTS "DirectMessage_receiverId_senderId_createdAt_idx"
  ON "DirectMessage"("receiverId", "senderId", "createdAt");

-- Counting unread messages per recipient.
CREATE INDEX IF NOT EXISTS "DirectMessage_receiverId_readAt_idx"
  ON "DirectMessage"("receiverId", "readAt");

DO $$
BEGIN
  ALTER TABLE "DirectMessage"
    ADD CONSTRAINT "DirectMessage_senderId_fkey"
    FOREIGN KEY ("senderId") REFERENCES "User"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE "DirectMessage"
    ADD CONSTRAINT "DirectMessage_receiverId_fkey"
    FOREIGN KEY ("receiverId") REFERENCES "User"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
