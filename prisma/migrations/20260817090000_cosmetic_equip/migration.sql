-- Equipped state for cosmetics.
--
-- A purchase previously recorded ownership but nothing marked an item as
-- being in use, so nothing bought in the store ever appeared in the game.
ALTER TABLE "PlayerCosmetic" ADD COLUMN "isEquipped" BOOLEAN NOT NULL DEFAULT false;

-- Owning the same cosmetic twice was only prevented in application code,
-- which leaves a race between two concurrent purchases. Drop any duplicates
-- that already exist before enforcing it.
DELETE FROM "PlayerCosmetic" a
  USING "PlayerCosmetic" b
 WHERE a."playerId"   = b."playerId"
   AND a."cosmeticId" = b."cosmeticId"
   AND a."ctid"       > b."ctid";

CREATE UNIQUE INDEX "PlayerCosmetic_playerId_cosmeticId_key"
    ON "PlayerCosmetic" ("playerId", "cosmeticId");

CREATE INDEX "PlayerCosmetic_playerId_cosmeticType_isEquipped_idx"
    ON "PlayerCosmetic" ("playerId", "cosmeticType", "isEquipped");
