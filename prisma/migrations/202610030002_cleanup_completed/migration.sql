-- Additive: NULL means pending/unknown cleanup, including legacy terminal rows.
ALTER TABLE "DownloadJob" ADD COLUMN "cleanupCompletedAt" TIMESTAMP(3);
CREATE INDEX "DownloadJob_state_cleanupCompletedAt_idx" ON "DownloadJob"("state", "cleanupCompletedAt");
