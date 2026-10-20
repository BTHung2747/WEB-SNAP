FROM wed-snap-media-curlcffi-lab:373-20261007
USER root
COPY labs/tiktok/cobalt/package.json labs/tiktok/cobalt/package-lock.json /opt/cobalt/
RUN cd /opt/cobalt && npm ci --ignore-scripts --omit=optional --no-audit --no-fund \
    && mkdir -p /lab && ln -s /opt/cobalt/node_modules /lab/node_modules \
    && cp /opt/cobalt/package.json /lab/package.json \
    && /opt/media/bin/python -c "import yt_dlp; assert yt_dlp.version.__version__ == '2026.08.19'"
WORKDIR /lab
LABEL com.wed-snap.lab="cobalt-tiktok" com.wed-snap.cobalt-commit="a636575b09de1fc55d9b8cd98cac88f5f2f16b42"
USER 1000:1000
