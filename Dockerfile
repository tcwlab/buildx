# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/buildx — Docker CLI + buildx plugin + git
#
# Dreistufiger Build:
#   1. docker/buildx-bin:0.33.0      → buildx-Binary
#   2. dhi.io/docker:29-cli          → Docker-CLI-Binary (distroless, nur Quelle)
#   3. dhi.io/alpine-base:3.23       → Runtime-Base (DHI-gehärtet, hat Shell + apk)
#
# dhi.io/docker:29-cli ist distroless (kein /bin/sh) → daher nur als Quell-Stage,
# nie als Runtime-Base für RUN-Befehle verwendbar.
#
# Kein Node.js — Checkout läuft per Shell (git init + git fetch).
#
# Usage als CI-Container:
#   container:
#     image: tcwlab/buildx:0.33.0
# ─────────────────────────────────────────────────────────────────────────────

FROM docker/buildx-bin:0.33.0 AS buildx-bin

FROM dhi.io/docker:29-cli AS docker-source

FROM dhi.io/alpine-base:3.23 AS release

COPY --from=docker-source /usr/local/bin/docker /usr/local/bin/docker
COPY --from=buildx-bin /buildx /usr/local/lib/docker/cli-plugins/docker-buildx

# DHI alpine-base runs as non-root by default — switch to root for package ops
USER root

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
