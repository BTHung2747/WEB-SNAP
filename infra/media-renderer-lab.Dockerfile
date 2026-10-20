# One lab-only layer chain; production/base tags are verified before/after build.
FROM wed-snap-media-curlcffi-lab:373-20261007
USER root
COPY playwright-core-1.63.0.tgz /tmp/playwright-core.tgz
RUN echo '208593d4e1bcd8f8fe5f869cad1cc332dc7f1d70dc1d58c102dc3ac36e30f26c  /tmp/playwright-core.tgz' | sha256sum -c - \
    && mkdir -p /opt/renderer /opt/pw-browsers \
    && tar -xzf /tmp/playwright-core.tgz -C /opt/renderer --strip-components=1 \
    && rm /tmp/playwright-core.tgz
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
RUN node /opt/renderer/cli.js install --with-deps --only-shell chromium \
    && /opt/media/bin/python -c "import yt_dlp; assert yt_dlp.version.__version__ == '2026.08.19'" \
    && dpkg-query -W > /opt/renderer-system-packages.txt \
    && find /opt/pw-browsers -type f -executable -exec sha256sum '{}' '+' > /opt/renderer-browser-sha256.txt
LABEL com.wed-snap.lab="renderer37" com.wed-snap.playwright="1.63.0" com.wed-snap.base-id="sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f"
USER 1000:1000
