# Exasol AI

A Docker-only installer that bundles three Exasol components into one local stack and brings them up with a **single command**:

- **Exasol Nano** — the local Exasol database
- **Exasol JSON Tables** — ingest, wrap, and query JSON in Exasol
- **Exasol MCP Server** — an LLM-facing, read-only access layer

After install you get **three standing containers** (`exasol-ai-nano`, `exasol-ai-mcp`, `exasol-ai-json-tables`), all bound to `127.0.0.1`.

> 📖 New here? The step-by-step guide is **[INSTALL.md](INSTALL.md)**.

---

Only prerequisite: **Docker** installed and running. There are two install methods — pick one.

### Method 1 — Script pipe (builds from source)

Works everywhere; the first run compiles the JSON Tables engine locally, so it takes a few minutes.

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

### Method 2 — Prebuilt images (pull from GHCR)

Fastest — pulls ready-made images (`ghcr.io/krishna-exasol/exasol-ai-json-tables` and `…-mcp`) instead of compiling. No Rust toolchain, no local build.

**Windows (PowerShell):**

```powershell
$env:EXASOL_PREBUILT="1"; irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

**macOS / Linux:**

```bash
EXASOL_PREBUILT=1 curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

The images are published to GHCR by the **Release images** workflow on each `v*` tag. Override the version with `EXASOL_IMAGE_TAG` (default `0.1.0`).

> **Note:** Method 2 requires the prebuilt-install support to be on the branch you fetch the installer from. Until it is merged to `main`, point the installer at this branch, e.g. `EXASOL_AI_REF=github-release-binary EXASOL_PREBUILT=1 curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/github-release-binary/install.sh | sh`.

Either way the installer downloads everything into `~/.exasol-ai/`, then starts the stack. From a local clone instead, run `.\install.ps1` / `./install.sh` (add `-Prebuilt` / `EXASOL_PREBUILT=1` for Method 2).

---

## What you get

| Container | Address | Notes |
| --- | --- | --- |
| `exasol-ai-nano` (SQL) | `127.0.0.1:8563` | user `sys`, password `exasol` |
| `exasol-ai-nano` (Web UI) | `https://127.0.0.1:8443` | only if the selected Nano image ships it |
| `exasol-ai-mcp` | `http://127.0.0.1:4896/mcp` | MCP protocol endpoint (`/health` for health) |
| `exasol-ai-json-tables` | _(no port)_ | CLI tool kept running; commands are `exec`'d into it |

Why three containers (and why JSON Tables and MCP are separate): JSON Tables needs `pyexasol>=2.2,<3` while MCP Server needs `pyexasol>=1,<2` — incompatible in one Python environment, so each runs isolated. See [DESIGN.md](DESIGN.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Use the JSON Tables CLI

The installer generates a helper that runs the CLI inside the standing container:

```powershell
~\.exasol-ai\run-json-tables.ps1 --help          # Windows
```
```bash
~/.exasol-ai/run-json-tables.sh --help           # macOS / Linux
```

Ingest a JSON file (place it in `~/.exasol-ai/workspace/` first):

```powershell
~\.exasol-ai\run-json-tables.ps1 ingest-and-wrap --input data.json --dsn nano:8563 --no-tls
```

> Inside the container the database is reached as **`nano:8563`** (the Docker service name), not `127.0.0.1` — always pass `--dsn nano:8563`.

Equivalent raw call (the helper just wraps this):

```bash
docker compose -f "$HOME/.exasol-ai/compose.yaml" --env-file "$HOME/.exasol-ai/.env" exec json-tables exasol-json-tables --help
```

---

## Files the installer creates

```text
~/.exasol-ai/
  compose.yaml              # Method 1 (source build)
  Dockerfile.mcp            # Method 1 only
  Dockerfile.json-tables    # Method 1 only
  compose.release.yaml      # Method 2 (prebuilt) — instead of the above three
  mcp-settings.json
  manifest.json
  .env
  run-json-tables.ps1 | run-json-tables.sh
  uninstall.ps1 | uninstall.sh
  workspace/
```

---

## Uninstall

Run the uninstall script from the install dir (the installer downloads it there):

```powershell
~\.exasol-ai\uninstall.ps1                # removes the stack, KEEPS data
~\.exasol-ai\uninstall.ps1 -RemoveData    # also deletes the data volume
```

If Windows blocks script execution, run it through PowerShell with a one-time policy bypass:

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.exasol-ai\uninstall.ps1"
```

```bash
~/.exasol-ai/uninstall.sh                 # removes the stack, KEEPS data
REMOVE_DATA=1 ~/.exasol-ai/uninstall.sh   # also deletes the data volume
```

By default the Docker volume with Nano data is preserved.

---

## Documentation

- **[INSTALL.md](INSTALL.md)** — quick start, verification, troubleshooting
- **[DESIGN.md](DESIGN.md)** — scope, dependency strategy, security defaults, release checklist
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — component integration deep-dive and caveats
- **[Installation methods comparison](https://krishna-exasol.github.io/exasol-ai/installation-methods.html)** — one-command install methods, ranked ([source](installation-methods.html))
- **[CHANGELOG.md](CHANGELOG.md)** · **[CONTRIBUTING.md](CONTRIBUTING.md)**

---

## Before public release

This is a development-grade MVP. Pin floating defaults before publishing:

- Nano image digest, not `latest`
- JSON Tables tag or commit, not `main`
- MCP Server exact package version (already `1.10.1`)
- Publish release assets + SHA256 checksums

---

## License

[MIT](LICENSE).
