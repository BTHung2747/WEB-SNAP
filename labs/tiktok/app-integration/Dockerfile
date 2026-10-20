FROM wed-snap-tiktok-cobalt-lab:20261008 AS cobalt
FROM wed-snap-app:local
USER root
COPY --from=cobalt /opt/cobalt/node_modules /app/apps/media/src/tiktok/node_modules
COPY apps/media/src /app/apps/media/src
COPY apps/media/src/media_adapter.py /app/infra/media_adapter.py
COPY apps/worker/src/adapter.ts /app/apps/worker/src/adapter.ts
USER node
LABEL com.wed-snap.lab="tiktok-app-integration"
