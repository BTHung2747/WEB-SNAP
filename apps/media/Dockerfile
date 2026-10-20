FROM node:22.22.3-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-venv ffmpeg ca-certificates tini && rm -rf /var/lib/apt/lists/*
COPY apps/media/requirements.lock /tmp/requirements-media.lock
RUN python3 -m venv /opt/media && /opt/media/bin/pip install --no-cache-dir -r /tmp/requirements-media.lock
ENV PATH="/opt/media/bin:${PATH}"
WORKDIR /app
COPY apps/media/src/media_adapter.py /app/infra/media_adapter.py
COPY apps/media/src/tiktok /app/infra/tiktok
RUN cd /app/infra/tiktok && npm ci --ignore-scripts --omit=optional --no-audit --no-fund
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
