CREATE TYPE "FeedbackKind" AS ENUM ('feedback', 'bug', 'idea');
CREATE TYPE "FeedbackStatus" AS ENUM ('unread', 'read', 'resolved');
CREATE TABLE "Feedback" (
    "id" TEXT NOT NULL,
    "kind" "FeedbackKind" NOT NULL,
    "subject" VARCHAR(120) NOT NULL,
    "message" VARCHAR(4000) NOT NULL,
    "name" VARCHAR(80),
    "email" VARCHAR(254),
    "status" "FeedbackStatus" NOT NULL DEFAULT 'unread',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Feedback_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "Feedback_createdAt_id_idx" ON "Feedback"("createdAt", "id");
CREATE INDEX "Feedback_status_createdAt_id_idx" ON "Feedback"("status", "createdAt", "id");
