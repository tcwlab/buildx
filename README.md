# tcwlab/buildx

Container-Image mit Docker CLI plus Buildx-Plugin für Multi-Arch-Container-Builds in Forgejo-CI-`container:`-Jobs.
Teil der [tcwlab](https://git.mon.k8b.co/tcwlab) Open-Source-Toolchain.

[![Docker Hub](https://img.shields.io/badge/docker-tcwlab%2Fbuildx-blue)](https://hub.docker.com/r/tcwlab/buildx)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Was steckt drin?

| Komponente | Version | Aufgabe |
|------------|---------|---------|
| Docker CLI | 29 | docker-Subkommandos (build, push, login, manifest, …) |
| Buildx | 0.33.0 | Multi-Arch-Builds, BuildKit-Frontend |
| git | apk-Default | Shell-basierter Checkout in `container:`-Jobs |

Bewusst kein Node.js — kein `actions/checkout`-Layer, weil wir in `container:`-Jobs lieber den schlanken Shell-Checkout-Pfad fahren.

## Verwendung in CI

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

    - name: Login Docker Hub
      env:
        DH_USER: ${{ secrets.DOCKERHUB_USERNAME }}
        DH_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
      run: echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin

    - name: Build (multi-arch)
      run: |
        docker buildx create --use --name ci-builder
        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          --tag tcwlab/myimage:${{ github.sha }} \
          --push .
```

Vollständiges Pipeline-Skelett mit Auto-Tag-Pattern: [`templates/docker-image-ci.yml`](https://git.mon.k8b.co/tcwlab/templates/src/branch/main/docker-image-ci.yml).

## Verfügbare Versionen

| Tag | Buildx | Docker CLI |
|-----|--------|------------|
| `tcwlab/buildx:0.33.0` | 0.33.0 | 29 |
| `tcwlab/buildx:latest` | rolling | rolling |

Konsumenten **immer** auf konkrete Buildx-Version pinnen.

## Update-Strategie

Buildx-Bumps und Docker-CLI-Major-Bumps werden manuell gemerged. Image-SemVer ist an die Buildx-Plugin-Version gebunden — die Docker-CLI-Major-Version steht in der OCI-Description, nicht im Image-Tag. Aktueller Snapshot: [`tcwlab/versions.yaml`](https://git.mon.k8b.co/tcwlab/).

Hinweis zu DinD: Forgejo-`container:`-Jobs haben standardmäßig keinen Docker-Daemon. Konsumenten brauchen entweder einen externen BuildKit-Daemon (Pattern in K8Box-CI) oder einen Host-Mount auf `/var/run/docker.sock`. Setup-Notes liegen aktuell in K8Box-internen Dokus.

## Lokaler Build

```bash
docker buildx build -t tcwlab/buildx:0.33.0 .
```

## Lizenz

Apache-2.0 — The Chameleon Way. Docker und Buildx stehen jeweils unter ihren eigenen Lizenzen (Apache-2.0).
