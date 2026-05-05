# buildx — Repository Context

> **Onboarding handshake:** Read in this order:
> 1. `Projects/CLAUDE.md` (global standards, workspace-local)
> 2. `tcwlab/CLAUDE.md` (toolchain context, workspace-local)
> 3. This file (buildx-specific)

---

## What is `buildx`?

`buildx` is the container image that bundles Docker CLI plus the `buildx` plugin — specifically for Forgejo CI `container:` jobs that build multi-architecture Docker images. Instead of relying on the host Docker daemon in each build job (which brings permission concerns, socket handling, and security implications), the build runs in the tcwlab image, which contains exactly the right tools.

The image is also the answer to a Forgejo action peculiarity: `container:` jobs do not include a DinD daemon. With `tcwlab/buildx`, the Buildx workflow can still be orchestrated in a consumer pipeline — typically against an external BuildKit daemon or the host daemon via volume mount.

### Consumers

Primary consumers are the `tcwlab` image repositories themselves (`betterlint`, `opentofu`, `trivy`, `semantic-release`, `buildx` itself — eating our own dogfood). Plus all consumer verticals that publish service containers to `tcwlab/<service>:*` or `harbor.k8b.io/*` — that is, K8Box service repos, Atrium verticals, Spectrum verticals, etc.

---

## What's inside?

[Dockerfile](https://github.com/tcwlab/buildx/blob/main/Dockerfile):

- **Stage 1 — `buildx-bin`**: `docker/buildx-bin:0.33.0` as the source for the Buildx plugin binary.
- **Stage 2 — `release`**: `docker:29-cli` as the base. Copies the Buildx binary to `/root/.docker/cli-plugins/docker-buildx`. `apk add git` for shell-based checkout in container jobs. Smoke test: `docker buildx version`.

Contents:

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker CLI | `29` | docker subcommands (build, push, login, manifest, …) |
| Buildx | `0.33.0` | Multi-architecture builds, BuildKit frontend |
| git | Alpine default | Shell-based checkout in `container:` jobs |

Intentionally **no** Node.js — we do not want to use Forgejo's JS-based `actions/checkout`, instead we prefer to stand on `git init && git fetch && git checkout`. Saves image footprint and avoids Node.js version dependencies.

ENTRYPOINT: empty. CMD: `sh`.

---

## Tool Versions and Pinning Strategy

The image tag reflects the Buildx plugin version: `tcwlab/buildx:0.33.0`. The Docker CLI major version is documented in the OCI description and in the image contents (`docker:29-cli`), but not reflected in the tag — Buildx is the application-relevant variable.

### Update Discipline

- **Buildx bump**: PR with `FROM docker/buildx-bin:<new-version>`, new image SemVer = new Buildx version.
- **Docker CLI major bump**: PR with `FROM docker:<n>-cli`, document in Dockerfile header ("v0.33.0 + Docker CLI v30"). Image SemVer remains tied to Buildx, but we recommend consumer pipelines re-run as a precaution.
- **Alpine major bump**: Indirectly through Docker CLI image updates. In the git apk path, no hard version pins, so we roll with the Alpine version.

---

## Release Procedure

`semantic-release` as in the other image repos: auto-tag from Conventional Commits, Forgejo release, Docker Hub push as `tcwlab/buildx:<x.y.z>` plus rolling `latest`.

---

## What to do on version bump

1. PR with Buildx and/or Docker CLI bump.
2. CI passes — smoke test (`docker buildx version`) must succeed.
3. **Consumer outreach** on Buildx major bump: other `tcwlab` image repos pin `BUILDX_VERSION` in their `ci.yml` `env:` block. On major bump, coordinate these values upward.
4. Update `versions.yaml`.

---

## What explicitly does NOT belong in this image

- **Build scripts** for specific consumer repos. `buildx` is a tool image, not a build orchestrator. Consumers have their own build scripts or use the `templates/docker-image-ci.yml` pattern.
- **Buildx builder configurations** (e.g., pre-initialized `buildx create --use` builder). Builder setup is the consumer's responsibility; differs per pipeline.
- **Registry login credentials**. Logins happen at runtime via `docker login` with secrets.
- **Cosign / sigstore tooling**. Image signing comes in a separate tcwlab image, not here.
- **Node.js**. Intentionally omitted — see above.

---

## Consumer Snippets

### Multi-arch build in a container job

```yaml
build:
  runs-on: ubuntu-22.04
  container:
    image: tcwlab/buildx:0.33.0
  steps:
    - name: Checkout (shell)
      run: |
        git init
        git remote add origin "https://${{ secrets.FORGEJO_TOKEN }}@${{ github.server_url }}/${{ github.repository }}.git"
        git fetch --depth=1 origin "${{ github.sha }}"
        git checkout FETCH_HEAD

    - name: Login (Docker Hub)
      env:
        DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
        DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
      run: echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

    - name: Build (multi-arch)
      run: |
        docker buildx create --use --name ci-builder
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t tcwlab/myimage:${{ github.sha }} \
          --push .
```

Complete pipeline with auto-tag pattern: [`templates/docker-image-ci.yml`](https://github.com/tcwlab/templates/blob/main/docker-image-ci.yml).

---

## Known Pain Points / Open Topics

- **DinD question**: In Forgejo container jobs, there is no Docker daemon. Consumers need either an external BuildKit daemon or a host mount (`/var/run/docker.sock`). Current practice is a dedicated BuildKit pod in the K8Box CI cluster — documentation lives in the onboarding of a K8Box repo, but should eventually become an ADR/doc here.
- **`apk add git` uses the Alpine default version**. On security vulnerabilities in git, we would have to push a base image update ourselves. Currently `git` is upgraded with `apk upgrade`, but not version-pinned — trade-off between reproducibility and security-patch velocity.
- **Buildx cache between CI runs**: Consumer pipelines must handle cache themselves via `--cache-from`/`--cache-to`. There is no centralized TCW cache backend — intentional, because setup and maintenance overhead do not fit current scale.
- **Bootstrap**: `buildx`'s own `ci.yml` must either use an older `tcwlab/buildx` tag or use host Docker, otherwise a chicken-and-egg problem.
