# buildx — Repo-Kontext

> **Onboarding-Handshake:** Lies in dieser Reihenfolge:
> 1. [`Projects/CLAUDE.md`](https://git.mon.k8b.co/) (globale Standards)
> 2. [`tcwlab/CLAUDE.md`](https://git.mon.k8b.co/tcwlab/) (Toolchain-Kontext)
> 3. Diese Datei (buildx-spezifisches)

---

## Was ist `buildx`?

`buildx` ist das Container-Image, das Docker-CLI plus das `buildx`-Plugin gebündelt liefert — speziell für Forgejo-CI-`container:`-Jobs, die multi-arch Docker-Images bauen. Statt in jedem Build-Job auf den Host-Docker zu setzen (was Permissions, Daemon-Sockets, Sicherheits-Implikationen mitbringt), läuft der Build im tcwlab-eigenen Image, das exakt die richtigen Tools enthält.

Das Image ist gleichzeitig die Antwort auf das Forgejo-Action-Eigenheit, dass `container:`-Jobs keinen DinD-Daemon mitbringen. Mit `tcwlab/buildx` lässt sich der Buildx-Workflow trotzdem in einer Konsumenten-Pipeline orchestrieren — typischerweise gegen einen externen BuildKit-Daemon oder den Host-Daemon via Volume-Mount.

### Konsumenten

Hauptkonsumenten sind die `tcwlab`-Image-Repos selbst (`betterlint`, `opentofu`, `trivy`, `semantic-release`, `buildx` selbst — Eat-our-own-Dogfood). Plus alle Konsumenten-Verticals, die Service-Container nach `tcwlab/<service>:*` oder `harbor.k8b.io/*` veröffentlichen — also K8Box-Service-Repos, Atrium-Verticals, Spectrum-Verticals usw.

---

## Was ist drin?

[Dockerfile](https://git.mon.k8b.co/tcwlab/buildx/src/branch/main/Dockerfile):

- **Stage 1 — `buildx-bin`**: `docker/buildx-bin:0.33.0` als Quelle für das Buildx-Plugin-Binary.
- **Stage 2 — `release`**: `docker:29-cli` als Basis. Kopiert das Buildx-Binary in `/root/.docker/cli-plugins/docker-buildx`. `apk add git` für Shell-basierten Checkout in container-Jobs. Smoke-Test: `docker buildx version`.

Inhalt:

| Komponente | Version | Aufgabe |
|------------|---------|---------|
| Docker CLI | `29` | docker-Subkommandos (build, push, login, manifest, …) |
| Buildx | `0.33.0` | Multi-Arch-Builds, BuildKit-Frontend |
| git | apk-Default | Shell-basierter Checkout in `container:`-Jobs |

Bewusst **kein** Node.js — wir wollen Forgejos JS-basierte `actions/checkout` *nicht* verwenden, sondern stehen unten lieber auf `git init && git fetch && git checkout`. Spart Image-Footprint und vermeidet Node-Version-Abhängigkeiten.

ENTRYPOINT: leer. CMD: `sh`.

---

## Tool-Versionen und Pinning-Strategie

Das Image-Tag spiegelt die Buildx-Plugin-Version: `tcwlab/buildx:0.33.0`. Die Docker-CLI-Major-Version steht in der OCI-Description und im Image-Inhalt (`docker:29-cli`), wird aber nicht im Tag gespiegelt — Buildx ist die anwendungsrelevante Variable.

### Update-Disziplin

- **Buildx-Bump**: PR mit `FROM docker/buildx-bin:<new-version>`, neue Image-SemVer = neue Buildx-Version.
- **Docker-CLI-Major-Bump**: PR mit `FROM docker:<n>-cli`, im Dockerfile-Header dokumentieren („v0.33.0 + Docker CLI v30"). Image-SemVer bleibt an Buildx gebunden, aber wir empfehlen, die Konsumenten-Pipelines dann sicherheitshalber neu durchlaufen zu lassen.
- **Alpine-Major-Bump**: Indirekt über Docker-CLI-Image-Wechsel. Im `git`-apk-Pfad keine harten Versions-Pins, also rollen wir mit der Alpine-Version mit.

---

## Release-Verfahren

`semantic-release` wie in den anderen Image-Repos: Auto-Tag aus Conventional-Commits, Forgejo-Release, Docker-Hub-Push als `tcwlab/buildx:<x.y.z>` plus rolling `latest`.

---

## Was bei Versions-Bump zu tun ist

1. PR mit Buildx- und/oder Docker-CLI-Bump.
2. CI durchlaufen — Smoke-Test (`docker buildx version`) muss durchlaufen.
3. **Konsumenten-Outreach** bei Buildx-Major-Bump: andere `tcwlab`-Image-Repos pinnen `BUILDX_VERSION` in ihrem `ci.yml`-`env:`-Block. Bei Major-Bump diese Werte koordiniert hochziehen.
4. `versions.yaml` aktualisieren.

---

## Was explizit NICHT in dieses Image gehört

- **Build-Skripte** für konkrete Konsumenten-Repos. `buildx` ist Werkzeug-Image, kein Build-Orchestrator. Konsumenten haben ihre eigenen Build-Skripte oder benutzen das `templates/docker-image-ci.yml`-Pattern.
- **Buildx-Builder-Konfigurationen** (z.B. vorinitialisierter `buildx create --use`-Builder). Builder-Setup ist Konsumenten-Sache; pro Pipeline meist anders.
- **Registry-Login-Credentials**. Logins erfolgen zur Laufzeit über `docker login` mit Secrets.
- **Cosign / sigstore-Tooling**. Image-Signing kommt in einem separaten tcwlab-Image, nicht hier.
- **Node.js**. Bewusst weggelassen — siehe oben.

---

## Konsumenten-Snippets

### Multi-Arch-Build im container-Job

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
          --tag tcwlab/myimage:${{ github.sha }} \
          --push .
```

Vollständige Pipeline mit Auto-Tag-Pattern: [`templates/docker-image-ci.yml`](https://git.mon.k8b.co/tcwlab/templates/src/branch/main/docker-image-ci.yml).

---

## Bekannte Schmerzpunkte / offene Themen

- **DinD-Frage**: in Forgejo-Container-Jobs gibt's keinen Docker-Daemon. Konsumenten brauchen entweder einen externen BuildKit-Daemon oder einen Host-Mount (`/var/run/docker.sock`). Aktuelle Praxis ist ein dedizierter BuildKit-Pod im K8Box-CI-Cluster — Doku dazu liegt aktuell im Onboarding eines K8Box-Repos, sollte aber irgendwann als ADR/Doku hier landen.
- **`apk add git` ist die Default-Version** der Alpine-Repos. Bei Sicherheitslücken in git müssten wir das Base-Image-Update selbst pushen. Aktuell `git` zwar mit-`apk-upgrade`d, aber nicht versions-pinned — Trade-off zwischen Reproduzierbarkeit und Security-Patch-Velocity.
- **Buildx-Cache zwischen CI-Runs**: Konsumenten-Pipelines müssen den Cache via `--cache-from`/`--cache-to` selbst handhaben. Es gibt keinen zentralen TCW-Cache-Backend — bewusst, weil das Setup und Maintenance-Overhead nicht zur aktuellen Skalierung passt.
- **Bootstrap**: `buildx`'s eigenes `ci.yml` muss entweder mit einem älteren `tcwlab/buildx`-Tag oder mit Host-Docker arbeiten, sonst Henne-Ei-Problem.
