# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/buildx — Docker CLI + buildx plugin + git
#
# Zweistufiger Build:
#   1. docker/buildx-bin:0.33.0   → buildx-Binary
#   2. docker:29-cli (Alpine 3.23) → Runtime-Base mit Docker CLI + Shell + apk
#
# Hinweis: dhi.io/alpine-base hat kein apk und ist daher als Build-Base
# für Images mit Package-Installation nicht geeignet.
#
# Kein Node.js — Checkout läuft per Shell (git init + git fetch).
#
# Usage als CI-Container:
#   container:
#     image: tcwlab/buildx:0.33.0
# ─────────────────────────────────────────────────────────────────────────────

FROM docker/buildx-bin:0.33.0 AS buildx-bin

FROM docker:29-cli AS release

COPY --from=buildx-bin /buildx /usr/local/lib/docker/cli-plugins/docker-buildx

# hadolint ignore=DL3018
RUN chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx \
    && apk upgrade --no-cache \
    && apk add --no-cache git \
    && docker buildx version \
    && addgroup -S ci \
    && adduser -S -G ci ci

USER ci
ENTRYPOINT []
CMD ["sh"]
