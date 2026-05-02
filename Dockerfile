# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/buildx — Docker CLI + buildx plugin + git
#
# Spezialisiertes CI-Container-Image für Build- und Publish-Jobs.
# Enthält genau das, was Forgejo-CI-Jobs für docker build / buildx brauchen:
#   - Docker CLI 27.x  (von docker:27-cli)
#   - buildx 0.19.3    (von docker/buildx-bin, multi-arch aware)
#   - git              (für Shell-basiertes Checkout in container:-Jobs)
#
# Kein Node.js — Checkout läuft per Shell (git init + git fetch).
#
# Usage als CI-Container:
#   container:
#     image: tcwlab/buildx:0.19.3
# ─────────────────────────────────────────────────────────────────────────────

FROM docker/buildx-bin:0.19.3 AS buildx-bin

FROM docker:27-cli AS release

COPY --from=buildx-bin /buildx /root/.docker/cli-plugins/docker-buildx

# hadolint ignore=DL3018
RUN chmod +x /root/.docker/cli-plugins/docker-buildx \
    && apk add --no-cache git \
    && docker buildx version

ENTRYPOINT []
CMD ["sh"]
