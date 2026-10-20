FROM python:3.12.12-slim-bookworm
WORKDIR /app
COPY apps/egress/src/egress.py .
COPY apps/egress/src/tiktok_policy ./tiktok_policy
COPY apps/egress/vendor ./vendor
COPY apps/egress/LICENSE apps/egress/NOTICE.md apps/egress/PROVENANCE.json ./
USER 65534:65534
CMD ["python", "egress.py"]
