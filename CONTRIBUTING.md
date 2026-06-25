# Contributing to Exasol AI

Thanks for your interest. This repository is the **installer / bundling layer** for
three Exasol components. Please read the ground rule before contributing.

## Ground rule: upstream components are never modified

Exasol AI bundles three upstream projects and consumes them **as-is**:

- [Exasol Nano](https://hub.docker.com/r/exasol/nano) — pulled Docker image
- [Exasol JSON Tables](https://github.com/exasol-labs/exasol-json-tables) — `git clone` + build
- [Exasol MCP Server](https://github.com/exasol/mcp-server) — `pip install`

**Do not fork or patch those repos as part of changes here.** All integration must
happen through configuration and orchestration in *this* repository: environment
variables the components already read, `mcp-settings.json`, Docker build args,
`compose.yaml`, the install/uninstall scripts, and the generated wrapper. If a
problem has no external lever, document it as a limitation rather than patching
upstream.

## Repository layout

```text
install.ps1 / install.sh        One-command installers (download assets, run compose)
uninstall.ps1 / uninstall.sh    Tear down the stack (optionally remove data)
compose.yaml                    The three-container stack definition
Dockerfile.mcp                  Builds the MCP Server image (pip)
Dockerfile.json-tables          Builds the JSON Tables image (Python + Rust via rustup)
mcp-settings.json               MCP read-only configuration
manifest.json                   Single source of truth for versions and ports
INSTALL.md / DESIGN.md          User and design docs
docs/ARCHITECTURE.md            Integration deep-dive and caveats
installation-methods.html       Comparison of install methods
SLIDES.md                       Slide-deck brief
```

## How the installer works

1. The one-liner downloads `install.ps1` / `install.sh`.
2. The script defaults its asset base URL to this repo's raw `main`, so a piped run
   (`irm | iex`, `curl | sh`) fetches `compose.yaml`, the Dockerfiles,
   `mcp-settings.json`, `manifest.json`, and the uninstall script into `~/.exasol-ai/`.
3. It writes `.env` from `manifest.json` and runs `docker compose up -d --build`.
4. It generates a `run-json-tables` helper that `exec`s the CLI into the standing
   JSON Tables container.

## Developing and testing locally

Prerequisites: Docker running, PowerShell 7+ (Windows) or POSIX `sh` (macOS/Linux).

```bash
# From a local clone (uses local files, not the network):
./install.sh                       # or  .\install.ps1  on Windows

# Verify:
docker compose -f ~/.exasol-ai/compose.yaml --env-file ~/.exasol-ai/.env ps
curl http://127.0.0.1:4896/health

# Tear down (keep data):
./uninstall.sh                     # or  .\uninstall.ps1
```

When testing the piped path, simulate the empty script-dir case:

```powershell
Get-Content .\install.ps1 -Raw | iex          # mimics: irm ... | iex
```
```bash
cat install.sh | sh                            # mimics: curl ... | sh
```

Useful overrides (env vars / params): `INSTALL_DIR`, `EXASOL_AI_BASE_URL`,
`EXASOL_AI_REF`, `SKIP_BUILD_TOOLS=1` (skip the slow JSON Tables build),
`NO_COLOR=1` (plain output).

## Pull requests

- Keep changes scoped to the installer/bundling layer.
- Update `CHANGELOG.md` under `[Unreleased]`.
- If behavior changes, update `README.md` / `INSTALL.md` so docs stay accurate.
- Test the actual install end-to-end — downloading a file is not the same as a
  working install (several past bugs only surfaced on a real run).
- Shell: target POSIX `sh` for `install.sh` (run `sh -n install.sh`); PowerShell 7+
  for `install.ps1`.
