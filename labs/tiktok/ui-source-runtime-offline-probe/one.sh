#!/bin/sh
set -u
role=$1
if [ "${2:-}" != INNER ]; then
 command -v timeout >/dev/null 2>&1 || { printf '{"kind":"failure","role":"%s","stage":"INTERNAL_WATCHDOG_UNAVAILABLE"}\n' "$role"; exit 20; }
 exec timeout -s KILL 15 /bin/sh /probe/one.sh "$role" INNER
fi
if ! /bin/sh /probe/guard.sh "$role"; then printf '{"kind":"failure","role":"%s","stage":"KERNEL_MAPPING_GUARD"}\n' "$role"; exit 20; fi
case "$role" in
 app)
  python3 -I -B /probe/media.py || exit 20
  if [ ! -f /app/node_modules/@prisma/client/package.json ] || [ ! -f /app/node_modules/prisma/build/index.js ]; then printf '{"kind":"failure","role":"app","stage":"CACHED_PRISMA_PACKAGE_MISSING"}\n'; exit 20; fi
  # Existing cached CLI only; no npx/npm/install or migration. Generated output
  # stays in the source-plan .prisma tmpfs. No engine or hints/survey requested.
  /app/node_modules/.bin/prisma generate --schema /app/prisma/schema.prisma --no-engine --no-hints >/tmp/offline-prisma.stdout 2>/tmp/offline-prisma.stderr
  gen=$?
  if [ "$gen" != 0 ]; then printf '{"kind":"failure","role":"app","stage":"OFFLINE_PRISMA_GENERATE","generatorExit":%s}\n' "$gen"; exit 20; fi
  exec /app/node_modules/.bin/tsx /probe/app.ts
  ;;
 proxy) exec python3 -I -B /probe/proxy.py ;;
 gateway) exec node /probe/gateway.cjs ;;
 postgres|redis)
  if [ "$role" = postgres ]; then version=$(postgres --version 2>/dev/null); code=$?; else version=$(redis-server --version 2>/dev/null); code=$?; fi
  if [ "$code" != 0 ]; then printf '{"kind":"failure","role":"%s","stage":"VERSION","versionExit":%s}\n' "$role" "$code"; exit 20; fi
  if ! printf '%s' "$version" | grep -Eq '^[A-Za-z0-9 .():=+_-]{1,256}$'; then printf '{"kind":"failure","role":"%s","stage":"VERSION_FORMAT"}\n' "$role"; exit 20; fi
  printf '{"kind":"role","role":"%s","ok":true,"version":"%s","serviceStarted":false}\n' "$role" "$version"
  ;;
 *) exit 20 ;;
esac
