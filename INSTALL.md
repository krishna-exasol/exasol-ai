# Exasol AI — Install & Quick Start

Exasol AI installs three components as one local stack, with a single command:

- **Exasol Nano** — the local Exasol database
- **Exasol MCP Server** — an LLM-facing, read-only access layer
- **Exasol JSON Tables** — a CLI tool to ingest, wrap, and query JSON in Exasol

Everything runs in Docker and binds to `127.0.0.1` (your machine only).

---

## 1. Prerequisites

- **Docker** installed and the engine running.
  - Windows/macOS: Docker Desktop (start it before installing).
  - Linux: Docker Engine + the Compose plugin.

That's the only prerequisite. The installer checks for it and stops with a clear message if Docker isn't running.

---

## 2. Install (one command)

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

The installer will:

1. Verify Docker is running.
2. Create `~/.exasol-ai/` and download the stack files there.
3. Start **Nano** and the **MCP Server**, and build the **JSON Tables** tool image.
4. Generate a `run-json-tables` helper script.

> First run takes several minutes: it pulls the Nano image, installs the MCP Server, and compiles the JSON Tables ingest engine. Later runs are fast.

### Faster install with prebuilt images (optional)

By default the installer builds the JSON Tables and MCP images from source (it
compiles the Rust ingest engine on your machine). You can instead pull
ready-made images from GHCR, which skips the local compile entirely:

**Windows (PowerShell):**

```powershell
$env:EXASOL_PREBUILT = "1"
irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

> Running a local copy instead? `.\install.ps1 -Prebuilt` does the same thing.

**macOS / Linux:**

```bash
EXASOL_PREBUILT=1 curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

This uses `compose.release.yaml` and pulls
`ghcr.io/krishna-exasol/exasol-ai-json-tables` and `…-mcp`. The images are
published by the **Release images** GitHub Actions workflow (`.github/workflows/release-images.yml`)
on each `v*` tag. Override the version with `EXASOL_IMAGE_TAG` (e.g. `0.1.0`).

---

## 3. What you get

Three standing containers run after install: `exasol-ai-nano`, `exasol-ai-mcp`, and `exasol-ai-json-tables`.

| Container | Address | Notes |
| --- | --- | --- |
| `exasol-ai-nano` (SQL) | `127.0.0.1:8563` | user `sys`, password `exasol` |
| `exasol-ai-nano` (Web UI) | `https://127.0.0.1:8443` | only if the selected Nano image ships it |
| `exasol-ai-mcp` (protocol) | `http://127.0.0.1:4896/mcp` | point your MCP client here |
| `exasol-ai-mcp` (health) | `http://127.0.0.1:4896/health` | returns `{"status":"healthy"}` |
| `exasol-ai-json-tables` | (no published port) | a CLI tool container, kept running idle; you `exec` commands into it (see below) |

Installed files (`~/.exasol-ai/`):

```text
~/.exasol-ai/
  compose.yaml
  Dockerfile.mcp
  Dockerfile.json-tables
  mcp-settings.json
  manifest.json
  .env
  run-json-tables.ps1   (Windows)  /  run-json-tables.sh  (macOS/Linux)
  workspace/            (put your JSON files here)
```

---

## 4. Verify it's running

```bash
# from the install directory
cd ~/.exasol-ai
docker compose --env-file .env -f compose.yaml ps
```

Health check:

```bash
curl http://127.0.0.1:4896/health
```

SQL check (any Exasol client, e.g. via the SQL port):

```sql
SELECT 1;
```

---

## 5. Connect an MCP client

Point any MCP-capable client (e.g. an LLM agent) at:

```
http://127.0.0.1:4896/mcp
```

The server is **read-only by default**: it can list metadata, run `SELECT` queries, and activate the JSON Tables preprocessor — but write queries and BucketFS writes are disabled (`mcp-settings.json`). It runs without client authentication, which is safe only because the port is bound to `127.0.0.1`.

---

## 6. Use the JSON Tables CLI

Use the generated helper. Show available commands:

**Windows:**

```powershell
~\.exasol-ai\run-json-tables.ps1 --help
```

**macOS / Linux:**

```bash
~/.exasol-ai/run-json-tables.sh --help
```

### Ingest a JSON file end to end

1. Put your file in the workspace folder so the container can see it:
   `~/.exasol-ai/workspace/data.json`
2. Run the full pipeline (ingest → build wrapper views + preprocessor → install):

**Windows:**

```powershell
~\.exasol-ai\run-json-tables.ps1 ingest-and-wrap --input data.json --dsn nano:8563 --no-tls
```

**macOS / Linux:**

```bash
~/.exasol-ai/run-json-tables.sh ingest-and-wrap --input data.json --dsn nano:8563 --no-tls
```

> **Important:** inside the tool container the database is reached as **`nano:8563`** (the Docker service name), not `127.0.0.1`. Always pass `--dsn nano:8563`. Use `--no-tls` for the local Nano import transport. User/password default to `sys` / `exasol`.

After this, an MCP client can activate the generated preprocessor (`set_exasol_preprocessor`) and query the JSON by path, e.g. `SELECT TO_JSON(*) FROM "<WRAPPER_SCHEMA>"."<VIEW>"`.

---

## 7. Stop / start / update

```bash
cd ~/.exasol-ai
docker compose --env-file .env -f compose.yaml stop     # stop, keep data
docker compose --env-file .env -f compose.yaml start    # start again
docker compose --env-file .env -f compose.yaml up -d --build   # rebuild/update
```

Your database data lives in the `exasol-ai-data` Docker volume and survives stop/start.

---

## 8. Uninstall

**Windows:**

```powershell
~\.exasol-ai\uninstall.ps1            # removes the stack, KEEPS data
~\.exasol-ai\uninstall.ps1 -RemoveData  # also deletes the data volume
```

**macOS / Linux:**

```bash
~/.exasol-ai/uninstall.sh             # removes the stack, KEEPS data
REMOVE_DATA=1 ~/.exasol-ai/uninstall.sh   # also deletes the data volume
```

---

## 9. Troubleshooting

- **"docker is required" / "engine is not running"** — start Docker Desktop (or the Docker daemon) and re-run.
- **First install is slow or fails mid-build** — it compiles the JSON Tables engine; ensure you have network access to Docker Hub, PyPI, and crates.io, then re-run the install command (it's safe to repeat).
- **JSON Tables "could not connect"** — make sure you passed `--dsn nano:8563` (not `127.0.0.1`) and `--no-tls`.
- **MCP JSON-path query fails intermittently** — the preprocessor is activated per session; have the client call `set_exasol_preprocessor` (and verify with `list_exasol_preprocessors`) before the query.

---

## 10. Defaults & security

- All ports bind to `127.0.0.1` only.
- Default credentials are `sys` / `exasol` — intended for local development.
- MCP is read-only by default; the MCP HTTP server runs without auth (acceptable only on localhost).
- Uninstall preserves your data volume unless you explicitly request removal.

These are development-grade defaults. See `DESIGN.md` for the release-hardening checklist (pinning versions, checksums) before any public or networked deployment.
