# tcwlab/buildx

> Docker CLI 29 + Buildx plugin 0.33.0 for multi-architecture container builds inside Forgejo CI `container:` jobs.
> Part of the [tcwlab](https://github.com/tcwlab) open-source CI/CD toolkit.

[![Docker Pulls](https://img.shields.io/docker/pulls/tcwlab/buildx?label=pulls)](https://hub.docker.com/r/tcwlab/buildx)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

---

## Quick start

```bash
docker pull tcwlab/buildx:latest

# Check versions
docker run --rm tcwlab/buildx:latest docker buildx version
docker run --rm tcwlab/buildx:latest git --version
```

Or as a Forgejo / GitHub-Actions container job:

```yaml
build:
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/buildx:latest
    env:
      DOCKER_HOST: tcp://docker-in-docker:2375
  steps:
    - name: Checkout (shell-based)
      run: |
        git init
        git remote add origin "https://${{ secrets.FORGEJO_TOKEN }}@${{ github.server_url }}/${{ github.repository }}.git"
        git fetch --depth=1 origin "${{ github.sha }}"
        git checkout FETCH_HEAD

    - name: Docker Hub Login
      env:
        DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
        DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
      run: echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

    - name: Build & Push (multi-arch)
      run: |
        docker buildx create --use --name ci-builder
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t myrepo/myimage:${{ github.sha }} \
          --push .
```

The image includes Git for shell-based checkout in `container:` jobs — no need for Node.js or `actions/checkout`.

> Quick-start examples use `:latest` so you can try the image immediately. For
> production CI pipelines, pin a concrete tag — see [Tags](#tags) below.

---

## Tags

> Version numbers below are illustrative. For the current set of tags, see
> [Docker Hub tags](https://hub.docker.com/r/tcwlab/buildx/tags).

| Tag | Description |
|-----|-------------|
| `tcwlab/buildx:0.33.0` | Concrete version (recommended for production) |
| `tcwlab/buildx:latest` | Rolling reference; always the newest release |

**Always pin a concrete version in production.** `latest` is fine for local testing, but pinning protects your pipeline from an unintended toolchain bump.

---

## Supported architectures

- `linux/amd64`
- `linux/arm64`

Every tag is a multi-arch manifest list. Docker automatically selects the right architecture for your host.

---

## What's included

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker CLI | 29 | docker subcommands (build, push, login, manifest, …) |
| Buildx | 0.33.0 | Multi-architecture builds, BuildKit frontend |
| git | Alpine default | Shell-based repository checkout in `container:` jobs |

Base image: `docker:29-cli`. Intentionally **no Node.js** — we rely on shell-based Git checkout instead of Node.js actions.

---

## Usage

### Multi-architecture build in a container job

```yaml
build:
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/buildx:0.33.0
    env:
      DOCKER_HOST: tcp://docker-in-docker:2375
  steps:
    - name: Checkout
      run: |
        git init
        git remote add origin "https://${{ secrets.FORGEJO_TOKEN }}@${{ github.server_url }}/${{ github.repository }}.git"
        git fetch --depth=1 origin "${{ github.sha }}"
        git checkout FETCH_HEAD

    - name: Build & Push
      run: |
        docker buildx create --use --name ci-builder
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t myrepo/myimage:latest \
          --push .
```

### Local build (single architecture)

```bash
docker buildx build -t myrepo/myimage:latest .
```

### Multi-architecture build with Buildx (requires QEMU on non-Linux hosts)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myrepo/myimage:latest \
  --push .
```

---

## Configuration

### Docker Daemon in Forgejo CI

Forgejo `container:` jobs do not include a Docker daemon by default. You have three options:

1. **DinD Service**: Add a Docker-in-Docker service sidecar to your job (requires elevated privileges).
2. **External BuildKit Daemon**: Point to a dedicated BuildKit pod (typical in K8Box environments).
3. **Host Socket Mount**: Mount `/var/run/docker.sock` from the runner (not recommended for security-sensitive pipelines).

Set `DOCKER_HOST=tcp://docker-in-docker:2375` (or the appropriate socket path) in your job `env:` block.

### QEMU for ARM64 Emulation

To build `linux/arm64` images on an `amd64` host, QEMU user-mode emulation is required:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Most CI runners (GitHub Actions, Forgejo cloud runners) include QEMU pre-installed. Self-hosted runners may need this step.

---

## Source & Issues

- **Source**: [github.com/tcwlab/buildx](https://github.com/tcwlab/buildx)
- **Issues**: [github.com/tcwlab/buildx/issues](https://github.com/tcwlab/buildx/issues)

---

## Build & Supply Chain

The image is built and published via Forgejo CI to Docker Hub at each SemVer release. Every build is:

- **Multi-architecture**: `linux/amd64` + `linux/arm64`
- **Scanned**: Trivy security scanner (HIGH/CRITICAL vulnerabilities only)
- **Pinned**: Docker CLI version 29, Buildx version 0.33.0
- **Reproducible**: Dockerfile and CI/CD pipeline are open-source and auditable

Image tags:
- `tcwlab/buildx:0.33.0` — immutable release tag (buildx version)
- `tcwlab/buildx:latest` — rolling reference to the newest release

---

## License

[Apache 2.0](LICENSE) — The Chameleon Way. Docker and Buildx remain under their respective licenses (Apache 2.0).
