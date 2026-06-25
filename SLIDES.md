# Exasol AI Installer — Slide Deck Brief

> **Purpose of this file:** source content for an AI slide generator ("Claude design").
> It is organized slide-by-slide. Each slide has a **Title**, **Content** (the bullets to
> render), a **Visual** suggestion (diagram/table the designer should draw), and **Notes**
> (speaker notes / context, not necessarily shown on the slide).
>
> **Audience:** technical stakeholders + decision makers. Adjust depth per slide as needed.
> **Suggested length:** ~18 slides (core deck). Slides marked _[deep-dive]_ are optional
> appendix material if a shorter deck is needed.
>
> All facts below are grounded in the implemented repository `krishna-exasol/exasol-ai`
> and the three upstream components it bundles.

---

## Slide 1 — Title

**Title:** Exasol AI — One-Command Local Install for Nano + JSON Tables + MCP Server

**Content:**
- A Docker-only installer that bundles three Exasol components into one local stack
- Installed and running with a single command
- MVP shipped and verified end-to-end

**Visual:** Three stacked layers / blocks labeled Nano, JSON Tables, MCP Server, joined by a single "1 command" arrow.

**Notes:** Set the framing: the product is the *integration/installer layer*, not the three components themselves.

---

## Slide 2 — What We're Bundling

**Title:** Three Components, One Goal

**Content:**
- **Exasol Nano** — the local Exasol database runtime (SQL + optional Web UI)
- **Exasol JSON Tables** — ingests JSON into queryable relational tables + a SQL preprocessor
- **Exasol MCP Server** — an LLM-facing, read-only access layer over the database
- **Goal:** install all three together with one command, working as an integrated whole

**Visual:** Three cards, each with an icon, a one-line role, and its "delivery" (pulled image / built from source / pip install).

**Notes:** Emphasize these are upstream-owned and consumed as-is (a hard project rule). All our work is the bundling layer.

---

## Slide 3 — The Core Constraint: Dependency Conflict

**Title:** Why Not Just One Container?

**Content:**
- JSON Tables requires `pyexasol >= 2.2, < 3`
- MCP Server (1.10.1) requires `pyexasol >= 1, < 2`
- The two ranges **do not overlap** — impossible in a single Python environment
- **Solution: runtime isolation** — each runs in its own container with its compatible dependency

**Visual:** A compatibility matrix table:

| Component | pyexasol | Python |
| --- | --- | --- |
| JSON Tables | `>=2.2.0,<3` | `>=3.10` |
| MCP Server 1.10.1 | `>=1.0.0,<2` | `>=3.10,<3.14` |

**Notes:** This single fact drives the entire multi-container architecture. It's not a style choice — it's forced.

---

## Slide 4 — Installation Methods: The Landscape

**Title:** How Could We Deliver "One Command"?

**Content:**
- We evaluated 12 distribution methods across reliability, approval friction, and platform fit
- Ranked from "best for MVP now" to "avoid as primary"
- Two dimensions matter: **reliability/integrity** and **time-to-ship**

**Visual:** A ranked horizontal bar or podium graphic of the top methods; full table on the next slide.

**Notes:** This is the "all methods explained" section the audience asked for. Lead with the landscape, then the detailed table, then the decision.

---

## Slide 5 — Installation Methods: Full Comparison _[deep-dive]_

**Title:** Method Comparison — Pros & Cons

**Content / Visual:** Render as a table.

| # | Method | Command shape | Reliability | Approval | Pros | Cons |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | GitHub Release + checksum | `irm …;Get-FileHash;.\install.ps1` | Very high | None | Strongest integrity; verifiable | Longer, multi-step command |
| 2 | GitHub Release pipe (`irm \| iex`) | `irm …/install.ps1 \| iex` | High | None | True one-liner; cross-platform | Pipe-to-exec trust; needs hosted assets |
| 3 | Homebrew custom tap | `brew tap …; brew install` | High | None | Fast macOS/Linux package path | Needs a tap repo; macOS/Linux only |
| 4 | Winget | `winget install …` | Very high | MS review | Mature Windows distribution | Needs signed installer + manifest |
| 5 | Homebrew core | `brew install exasol-ai` | Very high | Maintainer review | Trusted, discoverable | High bar: tagged release, audit, adoption |
| 6 | Raw GitHub pinned tag | `irm raw…/v0.1.0/install.ps1 \| iex` | Medium | None | Simple; no release infra | Unpinned `main` is risky for users |
| 7 | Scoop | `scoop install exasol-ai` | High | None (own bucket) | Good dev-Windows channel | Less universal than Winget |
| 8 | Chocolatey | `choco install exasol-ai` | High | Repo moderation | Enterprise Windows automation | Extra prerequisite for users |
| 9 | `uvx` bootstrap | `uvx exasol-ai@0.1.0 install` | High | PyPI | Clean isolated execution | Requires `uv` first |
| 10 | `pipx run` | `pipx run exasol-ai install` | Medium | PyPI | No Homebrew/Winget needed | More prerequisite friction |
| 11 | Docker Compose from URL | `docker compose -f <url> up` | Medium | None | Minimal | Can't handle wrapper scripts, config, uninstall |
| 12 | Docker socket bootstrap | `docker run -v /var/run/docker.sock …` | Avoid primary | None | Portable | Mounting the Docker socket is a security risk |

**Notes:** Keep this as the appendix "deep dive." For a short deck, collapse to top 3 + "avoid".

---

## Slide 6 — Our Decision

**Title:** What We Chose for the MVP

**Content:**
- **Method:** GitHub-hosted `irm | iex` (Windows) / `curl | sh` (macOS/Linux) bootstrap that drives Docker Compose
- **Why:** it's the only single-command form that also handles config, wrapper scripts, health checks, and uninstall
- **Path forward:** evolve toward Release-asset + SHA256 (#1) and pre-built images for speed/integrity

**Visual:** A "chosen" highlight on method #2, with arrows pointing to #1 (future hardening).

**Notes:** Bare `docker compose -f <url> up` (#11) was rejected: it can't build the on-demand tool image, write integration config, or provide uninstall.

---

## Slide 7 — The One-Command Experience

**Title:** Install in One Line

**Content:**
- **Windows (PowerShell):**
  `irm https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.ps1 | iex`
- **macOS / Linux:**
  `curl -fsSL https://raw.githubusercontent.com/krishna-exasol/exasol-ai/main/install.sh | sh`
- One prerequisite: **Docker** running. That's it.

**Visual:** A terminal mock showing the command and the `==> ...` progress lines ending in "Exasol AI MVP installed."

**Notes:** Live demo opportunity here if presenting.

---

## Slide 8 — What the Installer Does

**Title:** Under the One Command

**Content (numbered flow):**
1. Verify Docker engine is running
2. Create `~/.exasol-ai/` and download the stack files (compose, Dockerfiles, settings, manifest)
3. `docker compose up -d --build` → start all three containers
4. Generate a `run-json-tables` helper + uninstall scripts

**Visual:** A vertical flow diagram: One-liner → bootstrap script → fetch assets → docker compose → 3 containers.

**Notes:** The bootstrap defaults its download base URL to the repo's raw `main`, so a piped run with no local files still fetches every asset on its own.

---

## Slide 9 — Implemented Architecture

**Title:** The Running Stack

**Content:**
- `exasol-ai-nano` — database; ports `127.0.0.1:8563` (SQL), `:8443` (Web UI)
- `exasol-ai-mcp` — MCP server; `127.0.0.1:4896/mcp` (protocol), `/health`
- `exasol-ai-json-tables` — JSON Tables CLI as a standing container
- One Docker network; one named volume `exasol-ai-data` for durable DB state
- All ports bound to `127.0.0.1` (local only)

**Visual (diagram):**

```
                 ┌─────────────────────── Docker network ───────────────────────┐
   host:8563 ───▶│  exasol-ai-nano  ◀──────── SQL ──────── exasol-ai-mcp  │◀── host:4896 (/mcp,/health)
   host:8443 ───▶│   (database)     ◀── ingest/install ── exasol-ai-json-tables  │
                 └──────────────┬────────────────────────────────────────────────┘
                                │
                        volume: exasol-ai-data (/exa)
```

**Notes:** Stress: only the DB and MCP expose ports; JSON Tables has no port (it acts on the DB from inside the network).

---

## Slide 10 — Standing Containers Design Choice

**Title:** Three Containers, Always Present

**Content:**
- Nano + MCP are true services (long-running, listening)
- JSON Tables is a **CLI tool with no server process** — it normally runs and exits
- Design choice: keep it as a **standing container** (`entrypoint: sleep infinity`) so all three are visible and ready
- Commands run **into** it: `docker compose exec json-tables exasol-json-tables …`
- Trade-off: ~4 GB idle container in exchange for a consistent "all three present" model

**Visual:** Docker Desktop-style list showing three "Up" containers.

**Notes:** Alternative (on-demand `run --rm`) was the original design; we switched to standing containers per product preference.

---

## Slide 11 — The Integration Bridge (The Real Value)

**Title:** How the Three Actually Work Together

**Content:**
1. **JSON Tables** ingests JSON → relational "table-family" + installs wrapper views + a **SQL preprocessor** into Nano (one-time, needs DDL)
2. **MCP Server** activates that preprocessor per session: `set_exasol_preprocessor` → `ALTER SESSION SET SQL_PREPROCESSOR_SCRIPT = …`
3. **An LLM** then queries JSON by path through MCP — read-only

- Key insight: both tools use the **identical** `ALTER SESSION` handle — that's the bridge

**Visual:** A 3-step pipeline: JSON file → [JSON Tables installs query layer in Nano] → [MCP activates + serves] → LLM queries by path.

**Notes:** This is the "why bundle them" payoff: not three things side by side, but a JSON-over-SQL query surface exposed to an LLM.

---

## Slide 12 — The Table-Family Contract _[deep-dive]_

**Title:** How JSON Becomes Queryable Tables

**Content:**
- JSON is shredded into a family of relational tables, preserving:
  - **Objects** → child tables joined by `_id`
  - **Arrays** → `_arr` tables with `_parent` + `_pos` (order preserved)
  - **Variants** → one column per observed type
  - **Explicit null** → `|n` boolean markers (null vs absent)
- Wrapper views + a Lua preprocessor let users query by path: `meta.info.note`, `JOIN item IN s.items`, `TO_JSON(*)`

**Visual:** Left: a JSON doc. Right: the resulting tables (root, child object, array table) with arrows showing the mapping.

**Notes:** Optional depth. Drop for an exec audience; keep for engineers.

---

## Slide 13 — Security Defaults

**Title:** Safe-by-Default (for Local Dev)

**Content:**
- All ports bound to `127.0.0.1` only
- MCP is **read-only** by default (write queries + BucketFS writes disabled)
- Preprocessor activation works without write privilege (separate setting)
- Data volume preserved on uninstall unless explicitly removed
- Default creds `sys`/`exasol` and MCP `--no-auth` — acceptable **only** because it's localhost

**Visual:** A shield with a checklist; a callout box warning "localhost-bound = do not expose to 0.0.0.0 as-is."

**Notes:** Be explicit that these are dev-grade defaults; networked deployment needs hardening.

---

## Slide 14 — What Testing Caught _[deep-dive]_

**Title:** Real Bugs Found by Actually Running It

**Content:**
- **`irm | iex` crash:** `$PSScriptRoot` is empty when piped; `Join-Path` threw before its guard → fixed by guarding first
- **JSON Tables build failure:** Debian's `rustc 1.85` too old (a crate needs `>= 1.88`) → switched to **rustup** (built with 1.96)
- **Silent failure:** PowerShell didn't catch a failed `docker compose build` → added explicit exit-code checks
- Lesson: download-success ≠ install-success; only an end-to-end run proves it

**Visual:** Three "bug → fix" cards.

**Notes:** Strong slide for credibility — shows rigor. The first two are non-obvious and only surfaced via real execution.

---

## Slide 15 — Current Status

**Title:** MVP: Shipped & Verified

**Content:**
- One-command install live for Windows + macOS/Linux
- All three containers come up healthy; JSON Tables CLI runs
- Integration bridge (ingest → activate → query) understood and documented
- Docs: `INSTALL.md` (quick start), `DESIGN.md`, `installation-methods.html`

**Visual:** A green checklist of shipped items.

**Notes:** This is the "where we are" beat before "what's next."

---

## Slide 16 — Known Limitations

**Title:** Honest Limitations (MVP)

**Content:**
- **Unpinned versions:** Nano `:latest`, JSON Tables `main` — not reproducible yet
- **Build-at-install:** first run compiles the Rust engine (slow, ~minutes; ~4 GB image)
- **Session/pool caveat:** MCP pools connections; the per-session preprocessor can be dropped → mitigate with `EXA_POOL_SIZE=1`
- **Standing tool container:** idles using memory/disk by design

**Visual:** A simple "limitations → planned fix" two-column table.

**Notes:** Pair each limitation with the roadmap item on the next slide.

---

## Slide 17 — Roadmap / Hardening

**Title:** Path to Production

**Content:**
- **Pin everything:** Nano image digest, JSON Tables tag/commit, MCP exact version
- **Pre-built images → GHCR:** ship pull-not-compile (seconds, reproducible, checksummable)
- **Release + SHA256:** move from raw-`main` to versioned release assets (method #1)
- **Slim the tool image:** multi-stage build to drop the Rust toolchain
- **Bake `EXA_POOL_SIZE=1`** for a reliable JSON-path query bridge

**Visual:** A roadmap arrow: MVP (now) → Hardened (pinned + prebuilt) → Distributed (Winget/Homebrew).

**Notes:** Ties back to the methods slide: prebuilt images unlock the #1-ranked release+checksum path.

---

## Slide 18 — Summary

**Title:** One Command, Three Components, Working Together

**Content:**
- Forced multi-container design (dependency conflict) — solved cleanly
- Single-command bootstrap chosen over alternatives for completeness
- Three standing containers; integrated via the SQL-preprocessor bridge
- Shipped, tested, and documented; clear path to production hardening

**Visual:** Recap of the architecture diagram from Slide 9, simplified.

**Notes:** Close on the integration payoff, not just "it installs."

---

## Appendix — Reference Facts for the Designer

- Repo: `https://github.com/krishna-exasol/exasol-ai`
- Components: Nano (`docker.io/exasol/nano:latest`), JSON Tables (`exasol-labs/exasol-json-tables`, `main`), MCP Server (`exasol-mcp-server==1.10.1`)
- Ports: SQL 8563, Web 8443, MCP 4896 (all `127.0.0.1`)
- Activation SQL (the bridge): `ALTER SESSION SET SQL_PREPROCESSOR_SCRIPT = "<schema>"."<script>"`
- Rule: the three upstream repos are never modified; all work is in the installer layer
- Verified build: JSON Tables compiles with rustc 1.96.0 via rustup; all three containers reach "Up"
