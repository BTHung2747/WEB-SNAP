#!/bin/sh
set -eu
case "${ADMIN_PATH-}" in
  *[!a-z0-9/-]*) echo ADMIN_PATH_INVALID >&2; exit 20;;
esac
if ! printf '%s\n' "${ADMIN_PATH-}" | grep -Eq '^/[a-z][a-z0-9-]{19,63}$'; then
  echo ADMIN_PATH_INVALID >&2; exit 20
fi
case "$ADMIN_PATH" in
  /admin-*|/api-*|/assets-*|/brand-*|/privacy-*|/terms-*|/report-*|/ung-ho-*|/gop-y-*) echo ADMIN_PATH_INVALID >&2; exit 20;;
esac
exec "$@"
