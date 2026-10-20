#!/bin/bash
set -eu
node_modules/.bin/prisma generate --schema prisma/schema.prisma > /control/prisma-generate.log 2>&1
node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma > /control/prisma-migrate.log 2>&1
node_modules/.bin/tsx apps/api/src/main.ts > /control/api.log 2>&1 &
api=$!
trap 'kill -TERM "$api" 2>/dev/null || true; wait "$api" || true' EXIT
node_modules/.bin/tsx /fixture/offline.ts
