-- CreateEnum
CREATE TYPE "SurpriseStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED', 'DELETED');

-- CreateEnum
CREATE TYPE "Visibility" AS ENUM ('PRIVATE', 'UNLISTED');

-- CreateEnum
CREATE TYPE "AssetType" AS ENUM ('IMAGE');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "displayName" TEXT,
    "avatarUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Template" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "occasion" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "configuration" JSONB NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Template_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Surprise" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "occasion" TEXT NOT NULL DEFAULT 'birthday',
    "templateId" TEXT,
    "recipientName" TEXT NOT NULL,
    "recipientNickname" TEXT,
    "relationship" TEXT,
    "message" TEXT,
    "content" JSONB NOT NULL DEFAULT '{}',
    "theme" JSONB NOT NULL DEFAULT '{}',
    "slug" TEXT,
    "status" "SurpriseStatus" NOT NULL DEFAULT 'DRAFT',
    "visibility" "Visibility" NOT NULL DEFAULT 'UNLISTED',
    "publishedAt" TIMESTAMP(3),
    "publishedSnapshot" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Surprise_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Asset" (
    "id" TEXT NOT NULL,
    "surpriseId" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "type" "AssetType" NOT NULL DEFAULT 'IMAGE',
    "mimeType" TEXT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "size" INTEGER NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "confirmed" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Asset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Event" (
    "id" TEXT NOT NULL,
    "surpriseId" TEXT,
    "eventType" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Event_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Template_slug_version_key" ON "Template"("slug", "version");

-- CreateIndex
CREATE UNIQUE INDEX "Surprise_slug_key" ON "Surprise"("slug");

-- CreateIndex
CREATE INDEX "Surprise_userId_status_idx" ON "Surprise"("userId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "Asset_storageKey_key" ON "Asset"("storageKey");

-- CreateIndex
CREATE INDEX "Asset_surpriseId_sortOrder_idx" ON "Asset"("surpriseId", "sortOrder");

-- CreateIndex
CREATE INDEX "Event_eventType_createdAt_idx" ON "Event"("eventType", "createdAt");

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Surprise" ADD CONSTRAINT "Surprise_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Surprise" ADD CONSTRAINT "Surprise_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "Template"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Asset" ADD CONSTRAINT "Asset_surpriseId_fkey" FOREIGN KEY ("surpriseId") REFERENCES "Surprise"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_surpriseId_fkey" FOREIGN KEY ("surpriseId") REFERENCES "Surprise"("id") ON DELETE SET NULL ON UPDATE CASCADE;
