#!/bin/bash
set -eu
node_modules/.bin/prisma generate --schema prisma/schema.prisma > /dev/null 2>&1
node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma > /dev/null 2>&1
node_modules/.bin/tsx apps/api/src/main.ts > /dev/null 2>&1 &
api=$!
shutdown() {
 result=$?
 set +e
 kill -TERM "$api" 2>/dev/null
 wait "$api"
 api_exit=$?
 printf '{"apiActualExit":%s,"apiStopRequested":true}\n' "$api_exit" > /control/api-exit.json
 if [ "$result" = 0 ] && [ "$api_exit" != 0 ] && [ "$api_exit" != 143 ]; then result=1; fi
 exit "$result"
}
trap shutdown EXIT
node_modules/.bin/tsx /newlab/controller.ts
