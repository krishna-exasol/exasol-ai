# Exasol AI

A Docker-only installer that bundles three Exasol components into one local stack and brings them up with a **single command**:

- **Exasol Nano** — the local Exasol database
- **Exasol JSON Tables** — ingest, wrap, and query JSON in Exasol
- **Exasol MCP Server** — an LLM-facing, read-only access layer

After install you get **three standing containers** (`exasol-ai-nano`, `exasol-ai-mcp`, `exasol-ai-json-tables`), all bound to `127.0.0.1`.

> 📖 New here? The step-by-step guide is **[INSTALL.md](INSTALL.md)**.

---

## Install (one command)

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

Only prerequisite: **Docker** installed and running. The installer downloads everything into `~/.exasol-ai/`, then builds and starts the stack.

From a local clone instead, run `.\install.ps1` (Windows) or `./install.sh` (macOS/Linux).

A future pinned-release form will be:
`irm https://github.com/krishna-exasol/exasol-ai/releases/download/v0.1.0/install.ps1 | iex`

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
  compose.yaml
  Dockerfile.mcp
  Dockerfile.json-tables
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
- **[installation-methods.html](installation-methods.html)** — comparison of one-command install methods
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
