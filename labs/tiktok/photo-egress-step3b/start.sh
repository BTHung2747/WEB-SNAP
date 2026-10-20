#!/bin/bash
set -eu
node_modules/.bin/prisma generate --schema prisma/schema.prisma > /control/prisma-generate.log 2>&1
if [ "$1" = typecheck ]; then
  node --max-old-space-size=256 node_modules/typescript/bin/tsc -p tsconfig.json --noEmit
  exit
fi
node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma > /control/prisma-migrate.log 2>&1
EGRESS_TLS_MEDIA_FIXTURE=1 node_modules/.bin/tsx /fixture/worker_test.ts
