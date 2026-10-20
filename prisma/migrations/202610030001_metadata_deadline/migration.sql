-- Additive only. Legacy selectable rows stay NULL and expire conservatively.
-- Never backfill using updatedAt/ownerUntil (heartbeat can renew those).
ALTER TABLE "DownloadJob" ADD COLUMN "metadataAcceptedAt" TIMESTAMP(3),
                         ADD COLUMN "metadataExpiresAt" TIMESTAMP(3);
CREATE INDEX "DownloadJob_state_metadataExpiresAt_idx" ON "DownloadJob"("state", "metadataExpiresAt");
