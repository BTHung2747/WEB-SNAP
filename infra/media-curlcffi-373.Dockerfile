FROM wed-snap-media:2026.08.19
LABEL com.wed-snap.lab="tiktok-373" com.wed-snap.base-id="sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b"
USER root
COPY wheels/ /tmp/wheels/
COPY requirements.lock /tmp/requirements.lock
RUN /opt/media/bin/pip install --no-index --find-links=/tmp/wheels --only-binary=:all: --require-hashes --no-cache-dir -r /tmp/requirements.lock \
    && /opt/media/bin/pip check \
    && /opt/media/bin/python -c "import yt_dlp; assert yt_dlp.version.__version__ == '2026.08.19'" \
    && rm -rf /tmp/wheels /tmp/requirements.lock
USER 1000:1000
