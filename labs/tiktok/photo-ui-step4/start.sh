#!/bin/bash
set -eu
node_modules/.bin/prisma generate --schema prisma/schema.prisma > /control/prisma-generate.log 2>&1
if [ "$1" != backend ]; then
  node --max-old-space-size=256 node_modules/typescript/bin/tsc -p tsconfig.json --noEmit
  node --max-old-space-size=256 node_modules/typescript/bin/tsc -p apps/web/tsconfig.json --noEmit
  node --max-old-space-size=256 /fixture/build.mjs "$1"
  exit
fi
node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma > /control/prisma-migrate.log 2>&1
node_modules/.bin/tsx apps/api/src/main.ts > /control/api.log 2>&1 &
api=$!
EGRESS_TLS_MEDIA_FIXTURE=1 node_modules/.bin/tsx apps/worker/src/main.ts > /control/worker.log 2>&1 &
worker=$!
trap 'kill -TERM "$worker" "$api" 2>/dev/null || true; wait "$worker" || true; wait "$api" || true' EXIT
node_modules/.bin/tsx /fixture/backend_test.ts
