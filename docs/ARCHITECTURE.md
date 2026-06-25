# Exasol AI — Architecture & Integration

This document explains how the three bundled components fit together, the exact
mechanism that ties them into one queryable system, and the caveats that matter in
practice. It complements [DESIGN.md](../DESIGN.md) (scope/rationale) and
[INSTALL.md](../INSTALL.md) (user guide).

All facts here are grounded in the upstream source of the bundled components and the
installer in this repository. Per [CONTRIBUTING.md](../CONTRIBUTING.md), upstream is
never modified — every integration lever below lives in this repo.

## Components

| Component | Role | Delivery | Constraints |
| --- | --- | --- | --- |
| Exasol Nano | Local Exasol database | Pulled image (`docker.io/exasol/nano:latest`) | self-signed TLS |
| Exasol JSON Tables | Ingest JSON → relational tables; build wrapper views + SQL preprocessor | `git clone` + build (Python + Rust) | `pyexasol>=2.2,<3`, Python `>=3.10` |
| Exasol MCP Server | LLM-facing read access over the DB | `pip install exasol-mcp-server==1.10.1` | `pyexasol>=1,<2`, Python `>=3.10,<3.14` |

## Why three containers

JSON Tables requires `pyexasol>=2.2,<3`; MCP Server 1.10.1 requires `pyexasol>=1,<2`.
The ranges do not overlap, so they cannot share one Python environment. The stack
therefore isolates each in its own container. This is forced, not stylistic.

## Container topology

```
                 ┌────────────────── Docker network (exasol-ai_default) ──────────────────┐
  host:8563 ───▶ │  exasol-ai-nano  ◀──── SQL (nano:8563) ────  exasol-ai-mcp  │ ◀── host:4896 (/mcp, /health)
  host:8443 ───▶ │   (database)     ◀── ingest / install DDL ── exasol-ai-json-tables       │
                 └──────────────┬─────────────────────────────────────────────────────────┘
                                │
                        volume: exasol-ai-data  →  /exa  (durable DB state)
```

- Only Nano (SQL/Web) and MCP (HTTP) publish ports, all bound to `127.0.0.1`.
- JSON Tables has no port; it acts on the database from inside the network.
- Inside the network the database host is `nano` (the service name), so JSON Tables
  must connect with `--dsn nano:8563`, not `127.0.0.1`.

## Standing containers

Nano and MCP are long-running services. JSON Tables is a CLI tool with **no server
process** — left to its own entrypoint it would run a command and exit. To keep all
three present as standing containers, `compose.yaml` overrides its entrypoint with a
keep-alive (`sleep infinity`) and commands are run into it:

```bash
docker compose exec json-tables exasol-json-tables <args>
```

Trade-off: an idle ~4 GB container in exchange for a consistent "all three present"
model. (Alternative: on-demand `docker compose run --rm`, which leaves no standing
container.)

## The integration bridge (the point of bundling)

The three components combine into a JSON-over-SQL surface an LLM can query. The bridge
is a single shared handle — the SQL preprocessor — used identically by both tools.

1. **Install (one-time, needs DDL → runs as `sys`).** JSON Tables ingests JSON into a
   relational *table-family*, generates wrapper views, and installs a Lua **SQL
   preprocessor** script into Nano:

   ```sql
   ALTER SESSION SET SQL_PREPROCESSOR_SCRIPT = "<schema>"."<script>";
   ```

2. **Activate (per session, no write needed).** The MCP Server exposes
   `set_exasol_preprocessor`, which emits the *identical* `ALTER SESSION SET
   SQL_PREPROCESSOR_SCRIPT = ...`. This is gated by `enable_preprocessor_tools`
   (default on) — independent of `enable_write_query` — so it works under a read-only
   profile.

3. **Query (read-only).** With the preprocessor active, an LLM queries JSON by path
   through MCP, e.g. `SELECT TO_JSON(*) FROM "<WRAPPER>"."<VIEW>"`, or array iteration
   `JOIN item IN s.items`.

```
  data.json ──[JSON Tables: ingest + install query layer in Nano]──▶ Nano
                                                                       │
  LLM ──[MCP: set_exasol_preprocessor + SELECT]──────────────────────┘
```

## The table-family contract

JSON is shredded into related relational tables that preserve structure:

- **Objects** → child tables joined by `_id`.
- **Arrays** → `_arr` tables with `_parent` + `_pos` (order preserved).
- **Variants** (a field with multiple types) → one column per observed type.
- **Explicit null** → `|n` boolean marker columns (null vs absent).

Wrapper views plus the preprocessor expose this as JSON-path SQL.

## MCP configuration that matters

From the MCP server settings model:

- `enable_read_query` defaults **false** → `mcp-settings.json` sets it `true`, or
  JSON-path SELECTs can't run.
- `views.enable` defaults **false** → set `true` so wrapper views are visible.
- `enable_preprocessor_tools` defaults **true** → activation works in read-only mode.
- Write queries, summarize, profiling, and BucketFS read/write are disabled by default.

Connection environment (set in `compose.yaml`): `EXA_DSN=nano:8563`, `EXA_USER=sys`,
`EXA_PASSWORD=exasol`, `EXA_SSL_CERT_VALIDATION=false` (accepts Nano's self-signed
cert), `EXA_MCP_SETTINGS=/config/mcp-settings.json`. The HTTP server runs with
`--no-auth`, which only disables MCP-client OAuth — acceptable because the port is
localhost-only. Health is `GET /health`; the MCP protocol endpoint is `/mcp`.

## Caveats and limitations

- **Session pooling vs. the preprocessor (most important).** The MCP server pools DB
  connections. `set_exasol_preprocessor` runs `ALTER SESSION` on one pooled
  connection; a following query may run on a different one without it — the tool's own
  description warns about this. Mitigation (config-only, no upstream change): set
  `EXA_POOL_SIZE=1` on the MCP container so a single session is reused.
- **JSON Tables ignores env vars.** The CLI reads connection settings from flags, not
  the `EXASOL_*` env vars set on its service, and its default DSN (`127.0.0.1:8563`)
  is wrong inside the container. Always pass `--dsn nano:8563` (and `--no-tls` for the
  local import transport).
- **Read-only is slightly leaky.** `set_exasol_preprocessor` can point a session at
  any preprocessor present in the DB; a preprocessor rewrites all subsequent SQL.
  Bounded because installing one requires DDL (done only by JSON Tables as `sys`).
- **Unpinned versions / large image.** Nano `:latest`, JSON Tables `main`, and a
  ~4 GB tool image carrying the Rust toolchain. See the roadmap in
  [CHANGELOG.md](../CHANGELOG.md).

## Security defaults

- All ports bound to `127.0.0.1`.
- MCP read-only by default.
- Default credentials `sys`/`exasol` and MCP `--no-auth` — safe **only** on localhost.
- Uninstall preserves the data volume unless `-RemoveData` / `REMOVE_DATA=1`.

These are development-grade defaults; networked deployment requires hardening
(pinned versions, real credentials/auth, checksummed release assets).
