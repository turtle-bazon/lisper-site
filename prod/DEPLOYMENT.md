# lisper — Production Build & Deployment

Builds the production container image and describes deploying it with **Podman
Quadlet** (systemd user integration). Mirrors the layout used by
`link-short` (`../link-short/prod/`) so both services are deployed the same way.

All scripts live in this `prod/` directory. The project root is `$ROOT` below.

---

## 1. Overview

The build produces one OCI image `lisper:latest`, exported as a tarball. It is
assembled in **two stages** so the heavy Common Lisp compilation happens once in
a builder image and stays layer-cached across rebuilds.

| Script | Purpose |
|--------|---------|
| `prod/build` | Full build: stage1 + stage2 + tarball export |
| `prod/stage1-build` | Compile the CL binary in the builder image, extract it |
| `prod/stage2-build` | Build the slim runtime image from the pre-built binary |
| `prod/clean` | Prune dangling/untagged images |

| Build artifact | Value |
|----------------|-------|
| image name | `lisper:latest` |
| tarball | `build/lisper.tar` |
| intermediate binary | `build/lisper-stage1` |
| builder image | `lisper-builder:latest` |

**Only podman is needed on the build machine.** Unlike link-short there is no
npm step on the host: lisper's only non-SBCL build tool is `node`, and it is
installed *inside* the builder image (see §3).

---

## 2. Prerequisites

### On the build machine
- **podman** (rootless is fine — the stage-1 `apt-get` runs in the user namespace)
- Network access to `turtlebazon/bazon-lisp-dev` (builder) and
  `turtlebazon/bazon-lisp-prod` (runtime), plus Debian repos for `nodejs`
- No SBCL, no quicklisp, no node — the container has all of it

### Containerfiles
- `Container.stage1` — from `turtlebazon/bazon-lisp-dev`, installs `nodejs`,
  copies the Lisp sources, runs `make container-build` with
  `REQUIRE_NODE=1 BUILD_SUFFIX=-stage1`.
- `Container.stage2` — from `turtlebazon/bazon-lisp-prod`, copies
  `build/lisper-stage1` to `/app/lisper`, exposes 8080.

### Why node is needed at build time
`build-resources.lisp` compiles `jscl-tools/*.lisp` and `jscl-games/*.lisp` into
JS bundles with the vendored `jscl/jscl-node.js` and embeds them into
`src/jscl-bundles.lisp`. Without node the build used to *succeed* with an empty
bundle table, producing an image where the REPL, the games and the markdown
renderer 404 in the browser. `REQUIRE_NODE=1` (set by `Container.stage1`) now
makes a missing node — or fewer than 6 produced bundles — a hard error.

### What the runtime needs
Nothing but the executable: HTML/CSS/JS, the JSCL runtime, favicon and OG image
are all embedded in the binary at build time. There is **no** libpq/psql in the
image and none is needed — the `cl-postgres` fork implements the PostgreSQL wire
protocol in pure CL over `sb-bsd-sockets`.

---

## 3. Building

```bash
./prod/build              # binary + runtime image + build/lisper.tar
```

Runs, in order:

1. `prod/stage1-build` — `podman build -f Container.stage1 --build-arg
   BUILD_SUFFIX=-stage1 -t lisper-builder:latest $ROOT`, then
   `podman cp` of `build/lisper-stage1` out of the image.
2. `prod/stage2-build` — `podman build -f Container.stage2 -t lisper:latest $ROOT`.
3. `podman save lisper:latest -o build/lisper.tar`.

### Incremental builds
- **Only runtime contents changed** (rewrote `Container.stage2`): skip stage 1.
  ```bash
  ./prod/stage2-build
  ```
- **Lisp source changed**: `./prod/stage1-build && ./prod/stage2-build`.
- **Stale builder layer** (binary missing but build "succeeded"): `stage1-build`
  detects this and retries with `--no-cache` automatically; `./prod/clean` prunes
  dangling images.

> Layers are cached per `COPY` instruction, so editing `src/*.lisp` invalidates
> only the final `RUN make container-build`. Editing `jscl-tools/` invalidates
> from that `COPY` on — still cheap, since the SBCL core is cached in the base
> image layers.

### Local (non-container) build
Unchanged: `make build` on the dev box (SBCL + node required), binary at
`build/lisper`, `make dev-start` / `make dev-stop` for the dev server.

---

## 4. Configuration

The runtime container mounts (see `quadlet/lisper.container`):

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| `~/etc/lisper.conf` | `/etc/lisper.conf` (ro) | Runtime config |
| `~/data` | `/data` (ro) | GeoLite2 mmdb only |

A filled-in production example is in **`prod/lisper.conf.prod-example`**:

```bash
scp prod/lisper.conf.prod-example lisper@SERVER:~/etc/lisper.conf
```

Inside the container `:db-host` must be **`postgres`** (the quadlet
`NetworkAlias`), not `127.0.0.1`. `:geo-db-path` points at
`/data/maxmind/GeoLite2-Country.mmdb` (the `~/data` volume); if the file is
missing, geo analytics are simply disabled — not fatal.

The file is **one s-expression read with `(read s)`**: all keys must stay inside
the parentheses. Anything after the closing paren is silently ignored (that bug
once left `:site-url` at its default — see AGENTS.md).

### Secrets (all in `lisper.conf`, never in the image)
- `:admin-secret` — the secret in the hidden dashboard URL `/analytics/<secret>`
  (no login). Wrong secret → 404; `/admin/*` still requires an admin session.
- `:form-secret` — HMAC key for registration/login anti-spam tokens
  (falls back to `:admin-secret`).
- `:game-token` — bearer token for `POST /regexp-game`
  (falls back to the built-in default).
- `:db-password` — PostgreSQL role password.

### PostgreSQL init
`postgres.container` uses the Debian-style superuser `postgres` (change
`POSTGRES_PASSWORD`) and pre-creates the app role + database on first run via
`quadlet/postgres-init/001-create-lisper.sql`:

```sql
CREATE ROLE lisper WITH LOGIN PASSWORD 'lisper';
CREATE DATABASE lisper OWNER lisper;
GRANT ALL PRIVILEGES ON DATABASE lisper TO lisper;
```

**The schema is created by the app, not by init SQL** — lisper embeds its
migrations (`src/migrations.lisp`, 18 files) and applies pending ones on every
connect, so a fresh database is migrated automatically on first boot. The init
script only runs when `~/data/postgresql` is empty; to (re)apply it later:

```bash
podman exec -it systemd-postgres psql -U postgres -d postgres
```

Note the container name prefix: quadlet turns `postgres.container` into
`systemd-postgres`.

---

## 5. Quadlet (systemd containers)

`quadlet/` holds `.container` and `.network` units that the systemd *user*
session turns into services:

| Unit | Purpose |
|------|---------|
| `lisper.network` | User-defined podman network `lisper` |
| `postgres.container` | PostgreSQL 18-alpine (data in `~/data/postgresql`) |
| `lisper.container` | The lisper app (image `lisper:latest`, port 8080) |

Persistent state: `~/data/postgresql` (database) and `~/data/maxmind` (GeoIP).
The app container mounts `~/data` read-only — lisper writes nothing to disk.

`lisper.container`:
- mounts `~/etc/lisper.conf` → `/etc/lisper.conf` (ro) and `~/data` → `/data` (ro)
- publishes port 8080
- health check `bash -c '</dev/tcp/localhost/8080'` every 30s
- `After=`/`Wants=` `postgres.service` and `lisper-network.service`

> Dependency keys (`After=`, `Wants=`) must live in a `[Unit]` section. In
> `[Service]` systemd drops them with an "Unknown key 'After'" warning and the
> ordering never applies.

> PostgreSQL 18 moved `PGDATA` under a version subdirectory
> (`/var/lib/postgresql/18/docker`), which is why the unit mounts the *parent*
> `/var/lib/postgresql` — that keeps the data dir stable across PG versions.

---

## 6. Deploying to a server

On the **build machine**:
```bash
scp build/lisper.tar lisper@SERVER:~/lisper.tar
scp -r prod/quadlet/ lisper@SERVER:~/.config/containers/systemd/
scp prod/lisper.conf.prod-example lisper@SERVER:~/etc/lisper.conf   # then edit
```

On the **server**:
```bash
mkdir -p ~/etc ~/data/{postgresql,maxmind}
# optional: cp ~/GeoLite2-Country.mmdb ~/data/maxmind/
podman load -i ~/lisper.tar
systemctl --user daemon-reload
systemctl --user enable --now lisper-network.service postgres.service lisper.service
systemctl --user status lisper
journalctl --user -u lisper -f
```

Check the app can reach the database before blaming the proxy:
```bash
journalctl --user -u lisper | grep -i 'migrations complete\|db connect failed'
```

> Quadlet needs podman with systemd user integration; make sure `systemctl --user`
> works (enable lingering if there is no interactive login:
> `loginctl enable-linger lisper`).

---

## 7. Reverse proxy

Put the default (port 80) → `localhost:8080` proxy in front. Two ready-to-use
configs in `prod/proxy/`:

- `proxy/nginx.conf` (Nginx)
- `proxy/apache.conf` (Apache `mod_proxy`)

Replace the server name as needed and terminate TLS there. Both forward
`X-Real-IP` / `X-Forwarded-For` — **lisper's analytics depend on them**: without
those headers every visitor lands in the shared "unknown" IP bucket, so
per-country stats and rate limits degrade (see AGENTS.md).

---

## 8. Rollback

Keep the previous `build/lisper.tar` — `prod/build` deletes the tarball before
writing a new one.

```bash
podman load -i lisper-prev.tar
systemctl --user stop lisper.service
podman tag lisper:latest lisper:prev && podman tag lisper-prev:latest lisper:latest
systemctl --user start lisper.service
```

Database rollback is not covered by the image rollback: lisper only migrates
**up**. Take a dump before a risky deploy:

```bash
podman exec systemd-postgres pg_dump -U lisper lisper > ~/lisper-$(date +%F).sql
```
