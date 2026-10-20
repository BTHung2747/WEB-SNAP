#!/bin/bash
set -eu
cleanup() { kill -TERM "${api:-}" "${worker:-}" 2>/dev/null || true; wait "${api:-}" "${worker:-}" 2>/dev/null || true; }
trap cleanup EXIT TERM INT
node_modules/.bin/prisma generate --schema prisma/schema.prisma > /control/prisma-generate.log 2>&1
node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma > /control/prisma-migrate.log 2>&1
ffmpeg -v error -nostdin -f lavfi -i testsrc=size=64x64:rate=25 -f lavfi -i sine=frequency=440:sample_rate=44100 -t 2 -c:v libx264 -preset ultrafast -threads 1 -filter_threads 1 -pix_fmt yuv420p -c:a aac -b:a 32k /control/input.mp4
node_modules/.bin/tsx apps/api/src/main.ts > /control/api.log 2>&1 & api=$!
node_modules/.bin/tsx apps/worker/src/main.ts > /control/worker.log 2>&1 & worker=$!
node_modules/.bin/tsx /fixture/test_api.ts
