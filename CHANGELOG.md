# Changelog

All notable changes to the Exasol AI installer are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Pin Nano image digest, JSON Tables ref, and MCP Server version for reproducible installs.
- Publish pre-built images to GHCR so installs pull instead of compiling (faster, smaller, checksummable).
- Move from raw-`main` to versioned GitHub Release assets with SHA256 checksums.
- Slim the JSON Tables image with a multi-stage build (drop the Rust toolchain from the runtime).
- Set `EXA_POOL_SIZE=1` on the MCP container for a reliable per-session preprocessor bridge.

## [0.1.0] - 2026-06-25

First MVP: one-command, Docker-only install of Nano + JSON Tables + MCP Server.

### Added
- One-command install for Windows (`install.ps1`, `irm | iex`) and macOS/Linux (`install.sh`, `curl | sh`).
- `compose.yaml` running three containers: `exasol-ai-nano`, `exasol-ai-mcp`, `exasol-ai-json-tables`.
- All three run as **standing containers**; JSON Tables (a CLI tool with no server) is kept alive and invoked via `docker compose exec`.
- Generated `run-json-tables` helper and downloaded `uninstall` script in the install dir.
- Read-only MCP defaults (`mcp-settings.json`); all ports bound to `127.0.0.1`.
- Documentation: `README.md`, `INSTALL.md`, `DESIGN.md`, `docs/ARCHITECTURE.md`, `installation-methods.html`, `SLIDES.md`.
- Polished installer terminal UX: banner, numbered phases, status ticks, and a summary with next steps.
- `LICENSE` (MIT), `CHANGELOG.md`, `CONTRIBUTING.md`.

### Fixed
- `install.ps1` crashed when piped to `iex` because `$PSScriptRoot` was empty and `Join-Path` threw; the local-copy branch is now guarded.
- JSON Tables build failed with Debian's `rustc` 1.85 (a transitive crate needs `>= 1.88`); the Dockerfile now installs a modern toolchain via rustup.
- `install.ps1` now checks `docker compose` exit codes and fails loudly instead of reporting a successful install after a failed build.

### Known limitations
- Versions are unpinned (Nano `:latest`, JSON Tables `main`).
- First install compiles the Rust ingest engine (slow; large ~4 GB tool image).
- The MCP server pools connections, so a session-scoped preprocessor may be dropped between calls (mitigate with `EXA_POOL_SIZE=1`).

[Unreleased]: https://github.com/krishna-exasol/exasol-ai/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/krishna-exasol/exasol-ai/releases/tag/v0.1.0
