# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/buildx — Docker CLI + buildx plugin + git
#
# Spezialisiertes CI-Container-Image für Build- und Publish-Jobs.
# Enthält genau das, was Forgejo-CI-Jobs für docker build / buildx brauchen:
#   - Docker CLI 29.x  (von dhi.io/docker:29-cli — Docker Hardened Image)
#   - buildx 0.33.0    (von docker/buildx-bin, multi-arch aware)
#   - git              (für Shell-basiertes Checkout in container:-Jobs)
#
# Kein Node.js — Checkout läuft per Shell (git init + git fetch).
#
# Usage als CI-Container:
#   container:
#     image: tcwlab/buildx:0.33.0
# ─────────────────────────────────────────────────────────────────────────────

FROM docker/buildx-bin:0.33.0 AS buildx-bin

FROM dhi.io/docker:29-cli AS release

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
