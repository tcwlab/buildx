# ─────────────────────────────────────────────────────────────────────────────
# tcwlab/buildx — Docker CLI + buildx plugin + git
#
# Specialized CI container image for build and publish jobs.
# Contains exactly what Forgejo CI jobs need for docker build / buildx operations:
#   - Docker CLI 29.x  (from docker:29-cli)
#   - buildx 0.33.0    (from docker/buildx-bin, multi-arch aware)
#   - git              (for shell-based checkout in container: jobs)
#
# No Node.js — checkout runs via shell (git init + git fetch).
#
# Usage as CI container:
#   container:
#     image: tcwlab/buildx:0.33.0
# ─────────────────────────────────────────────────────────────────────────────

FROM docker/buildx-bin:0.33.0 AS buildx-bin

FROM docker:29-cli AS release

COPY --from=buildx-bin /buildx /root/.docker/cli-plugins/docker-buildx

# hadolint ignore=DL3018
RUN chmod +x /root/.docker/cli-plugins/docker-buildx \
    && apk add --no-cache git \
    && docker buildx version

ENTRYPOINT []
CMD ["sh"]
