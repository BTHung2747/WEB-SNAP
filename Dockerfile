FROM node:22.22.3-bookworm-slim AS dependencies
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv ffmpeg ca-certificates tini && rm -rf /var/lib/apt/lists/*
COPY apps/media/requirements.lock /tmp/requirements-media.lock
RUN python3 -m venv /opt/media && /opt/media/bin/pip install --no-cache-dir -r /tmp/requirements-media.lock
ENV PATH="/opt/media/bin:${PATH}"
ENV NODE_OPTIONS="--max-old-space-size=384"
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json
COPY apps/worker/package.json apps/worker/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN npm ci --no-audit --no-fund
FROM dependencies AS app
COPY tsconfig.json ./
COPY apps ./apps
COPY packages ./packages
COPY prisma ./prisma
COPY scripts/create-admin.ts ./scripts/create-admin.ts
# Preserve the worker/fixture entrypoint while source lives in apps/media.
COPY apps/media/src/media_adapter.py /app/infra/media_adapter.py
RUN cd /app/apps/media/src/tiktok && npm ci --ignore-scripts --omit=optional --no-audit --no-fund
RUN npm run build
RUN mkdir -p /media && chown node:node /media
USER node
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["node", "dist/apps/api/src/main.js"]
