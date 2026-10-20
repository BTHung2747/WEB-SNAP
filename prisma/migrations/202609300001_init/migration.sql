-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "csrf" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminUser" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DownloadJob" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "sourceUrl" TEXT,
    "state" TEXT NOT NULL DEFAULT 'analyzing',
    "errorCode" TEXT,
    "title" TEXT,
    "duration" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "ownerUntil" TIMESTAMP(3) NOT NULL,
    "releaseAt" TIMESTAMP(3),
    "cancelRequested" BOOLEAN NOT NULL DEFAULT false,
    "prepareKey" TEXT,
    "formatId" TEXT,
    "processUntil" TIMESTAMP(3),
    "workerToken" TEXT,

    CONSTRAINT "DownloadJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MediaItem" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "formats" JSONB NOT NULL,

    CONSTRAINT "MediaItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TemporaryAsset" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "state" TEXT NOT NULL DEFAULT 'staging',
    "path" TEXT NOT NULL,
    "size" BIGINT NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readyUntil" TIMESTAMP(3),
    "transferDeadline" TIMESTAMP(3),
    "retryUntil" TIMESTAMP(3),

    CONSTRAINT "TemporaryAsset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TransferLease" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "state" TEXT NOT NULL DEFAULT 'started',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "bytes" BIGINT NOT NULL DEFAULT 0,
    "reserved" BIGINT NOT NULL,
    "month" TEXT NOT NULL,
    "endedAt" TIMESTAMP(3),

    CONSTRAINT "TransferLease_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DownloadTicket" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DownloadTicket_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EgressBudget" (
    "month" TEXT NOT NULL,
    "charged" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "EgressBudget_pkey" PRIMARY KEY ("month")
);

-- CreateTable
CREATE TABLE "AdCampaign" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "imageUrl" TEXT,
    "targetUrl" TEXT NOT NULL,
    "linkType" TEXT NOT NULL DEFAULT 'sponsored',
    "placement" TEXT NOT NULL DEFAULT 'banner',
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "weight" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "AdCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdEvent" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Settings" (
    "id" TEXT NOT NULL DEFAULT 'main',
    "value" JSONB NOT NULL,

    CONSTRAINT "Settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "detail" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_email_key" ON "AdminUser"("email");

-- CreateIndex
CREATE INDEX "DownloadJob_state_ownerUntil_idx" ON "DownloadJob"("state", "ownerUntil");

-- CreateIndex
CREATE UNIQUE INDEX "TemporaryAsset_jobId_key" ON "TemporaryAsset"("jobId");

-- CreateIndex
CREATE INDEX "TransferLease_state_expiresAt_idx" ON "TransferLease"("state", "expiresAt");

-- CreateIndex
CREATE INDEX "AdEvent_createdAt_idx" ON "AdEvent"("createdAt");

-- AddForeignKey
ALTER TABLE "DownloadJob" ADD CONSTRAINT "DownloadJob_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MediaItem" ADD CONSTRAINT "MediaItem_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "DownloadJob"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TemporaryAsset" ADD CONSTRAINT "TemporaryAsset_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "DownloadJob"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TransferLease" ADD CONSTRAINT "TransferLease_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "TemporaryAsset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DownloadTicket" ADD CONSTRAINT "DownloadTicket_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "DownloadJob"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AdEvent" ADD CONSTRAINT "AdEvent_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "AdCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;
