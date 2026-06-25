# Exasol AI Installer Design

## Scope

Exasol AI is a Docker-only MVP installer that bundles:

- Exasol Nano as the local Exasol database runtime
- Exasol JSON Tables as the JSON ingest, wrapper, query, and reshape tool
- Exasol MCP Server as the LLM-facing Exasol access layer

The product name is Exasol AI. The documentation may still refer to JSON Tables and MCP Server as component names.

## MVP Install Commands

Windows PowerShell (raw from `main`, works today):

```powershell
irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex
```

macOS / Linux (raw from `main`, works today):

```bash
curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh
```

Pinned GitHub Release form (after a release is published):

```powershell
irm https://github.com/krishna-exasol/exasol-ai/releases/download/v0.1.0/install.ps1 | iex
```

```bash
curl -fsSL https://github.com/krishna-exasol/exasol-ai/releases/download/v0.1.0/install.sh | sh
```

## Runtime Layout

The installer writes local state to:

```text
~/.exasol-ai/
```

Docker services:

- `exasol-ai-nano`: Exasol Nano database
- `exasol-ai-mcp`: Exasol MCP Server
- `json-tables`: on-demand tool container for Exasol JSON Tables

Docker volume:

- `exasol-ai-data`

## Dependency Conflict Strategy

Exasol JSON Tables currently requires `pyexasol>=2.2,<3`, while Exasol MCP Server currently requires `pyexasol>=1,<2`.

Compatibility matrix:

| Component | `pyexasol` | Python | Source |
| --- | --- | --- | --- |
| JSON Tables | `>=2.2.0,<3` | `>=3.10` | `jt/pyproject.toml:13` |
| MCP Server 1.10.1 | `>=1.0.0,<2` | `>=3.10,<3.14` due to `numpy` | `mcp/pyproject.toml:21-22` |

The MVP solution is runtime isolation:

- MCP Server runs in its own container with its compatible `pyexasol` dependency.
- JSON Tables runs in its own tool container with its compatible `pyexasol` dependency.

This is more reliable than trying to force both packages into one Python environment.

## Security Defaults

- Bind exposed ports to `127.0.0.1`.
- Keep MCP read-only by default.
- Disable write query and BucketFS writes by default.
- Do not print secrets in logs.
- Preserve Nano data during uninstall unless the user explicitly requests data removal.

## Release Hardening Checklist

- Replace `docker.io/exasol/nano:latest` with a tested tag or image digest.
- Replace JSON Tables `main` with a tested tag or commit.
- Keep MCP Server pinned to an exact package version.
- Publish installer files as GitHub Release assets.
- Publish SHA256 checksums.
- Add a full smoke test once Docker is running:
  - Nano starts.
  - SQL `SELECT 1` succeeds.
  - MCP health endpoint responds.
  - JSON Tables CLI starts.
  - Optional: ingest a tiny JSON file, install wrapper, activate preprocessor, query `TO_JSON(*)`.
