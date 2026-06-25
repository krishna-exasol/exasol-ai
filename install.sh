#!/usr/bin/env sh
set -eu

INSTALL_DIR="${INSTALL_DIR:-"$HOME/.exasol-ai"}"
NANO_IMAGE="${EXASOL_NANO_IMAGE:-docker.io/exasol/nano:latest}"
JSON_TABLES_REF="${EXASOL_JSON_TABLES_REF:-main}"
MCP_SERVER_VERSION="${EXASOL_MCP_SERVER_VERSION:-1.10.1}"
SQL_PORT="${EXASOL_SQL_PORT:-8563}"
WEB_PORT="${EXASOL_WEB_PORT:-8443}"
MCP_PORT="${EXASOL_MCP_PORT:-4896}"
SKIP_BUILD_TOOLS="${SKIP_BUILD_TOOLS:-0}"
EXASOL_AI_REF="${EXASOL_AI_REF:-main}"
EXASOL_AI_BASE_URL="${EXASOL_AI_BASE_URL:-https://raw.githubusercontent.com/krishna-exasol/exasol-ai/${EXASOL_AI_REF}}"

# Prebuilt mode: pull ready-made images from GHCR instead of building the
# JSON Tables / MCP images from source. Off by default so this path is
# identical to the proven source build unless explicitly requested.
EXASOL_PREBUILT="${EXASOL_PREBUILT:-0}"
IMAGE_REGISTRY="${EXASOL_IMAGE_REGISTRY:-ghcr.io/krishna-exasol}"
IMAGE_TAG="${EXASOL_IMAGE_TAG:-0.1.0}"
JSON_TABLES_IMAGE="${EXASOL_JSON_TABLES_IMAGE:-$IMAGE_REGISTRY/exasol-ai-json-tables:$IMAGE_TAG}"
MCP_IMAGE="${EXASOL_MCP_IMAGE:-$IMAGE_REGISTRY/exasol-ai-mcp:$IMAGE_TAG}"

if [ "$EXASOL_PREBUILT" = "1" ]; then
  COMPOSE_FILE="compose.release.yaml"
else
  COMPOSE_FILE="compose.yaml"
fi

# ---------------------------------------------------------------------------
# Pretty output helpers (colors only on an interactive terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_CYAN="$(printf '\033[36m')"; C_GREEN="$(printf '\033[32m')"
  C_YEL="$(printf '\033[33m')";  C_GRY="$(printf '\033[90m')"
  C_WHT="$(printf '\033[97m')";  C_RST="$(printf '\033[0m')"
else
  C_CYAN=""; C_GREEN=""; C_YEL=""; C_GRY=""; C_WHT=""; C_RST=""
fi

PHASE=0
TOTAL=5

banner() {
  printf '\n'
  printf '  %s=================================================%s\n' "$C_CYAN" "$C_RST"
  printf '  %s Exasol AI Installer%s\n' "$C_WHT" "$C_RST"
  printf '  %s Nano  +  JSON Tables  +  MCP Server%s\n' "$C_GRY" "$C_RST"
  printf '  %s=================================================%s\n' "$C_CYAN" "$C_RST"
}

phase() {
  PHASE=$((PHASE + 1))
  printf '\n  %s[%d/%d]%s %s%s%s\n' "$C_CYAN" "$PHASE" "$TOTAL" "$C_RST" "$C_WHT" "$1" "$C_RST"
}

ok()   { printf '      %s✓%s %s%s%s\n' "$C_GREEN" "$C_RST" "$C_GRY" "$1" "$C_RST"; }
info() { printf '        %s%s%s\n' "$C_GRY" "$1" "$C_RST"; }
warn() { printf '      %s! %s%s\n' "$C_YEL" "$1" "$C_RST"; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '%s is required. %s\n' "$1" "$2" >&2
    exit 1
  fi
}

copy_or_download_asset() {
  name="$1"
  destination="$2"
  local_path="$SCRIPT_DIR/$name"
  if [ -n "$SCRIPT_DIR" ] && [ -f "$local_path" ]; then
    cp "$local_path" "$destination"
    ok "$name (local)"
    return
  fi
  if [ -z "${EXASOL_AI_BASE_URL:-}" ]; then
    printf 'Cannot find local asset %s and EXASOL_AI_BASE_URL is not set.\n' "$name" >&2
    exit 1
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$EXASOL_AI_BASE_URL/$name" -o "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$EXASOL_AI_BASE_URL/$name" -O "$destination"
  else
    printf 'curl or wget is required to download installer assets.\n' >&2
    exit 1
  fi
  ok "$name"
}

SCRIPT_PATH="${0:-}"
case "$SCRIPT_PATH" in
  /*) SCRIPT_DIR="$(dirname "$SCRIPT_PATH")" ;;
  */*) SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)" ;;
  *) SCRIPT_DIR="" ;;
esac

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
banner

phase "Checking prerequisites"
need docker "Install Docker and start the Docker engine."
ok "docker found"
docker info >/dev/null 2>&1 || { printf '\nDocker is installed but the engine is not running. Start Docker and re-run.\n' >&2; exit 1; }
ok "Docker engine is running"

phase "Downloading stack files"
info "into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/workspace"
if [ "$EXASOL_PREBUILT" = "1" ]; then
  ASSETS="compose.release.yaml mcp-settings.json manifest.json uninstall.sh"
else
  ASSETS="compose.yaml Dockerfile.mcp Dockerfile.json-tables mcp-settings.json manifest.json uninstall.sh"
fi
for asset in $ASSETS; do
  copy_or_download_asset "$asset" "$INSTALL_DIR/$asset"
done

phase "Configuring"
cat > "$INSTALL_DIR/.env" <<EOF
EXASOL_NANO_IMAGE=$NANO_IMAGE
EXASOL_JSON_TABLES_REF=$JSON_TABLES_REF
EXASOL_MCP_SERVER_VERSION=$MCP_SERVER_VERSION
EXASOL_JSON_TABLES_IMAGE=$JSON_TABLES_IMAGE
EXASOL_MCP_IMAGE=$MCP_IMAGE
EXASOL_SQL_PORT=$SQL_PORT
EXASOL_WEB_PORT=$WEB_PORT
EXASOL_MCP_PORT=$MCP_PORT
EOF
ok "Nano image:   $NANO_IMAGE"
if [ "$EXASOL_PREBUILT" = "1" ]; then
  ok "JSON Tables:  $JSON_TABLES_IMAGE (prebuilt)"
  ok "MCP Server:   $MCP_IMAGE (prebuilt)"
else
  ok "JSON Tables:  $JSON_TABLES_REF"
  ok "MCP Server:   $MCP_SERVER_VERSION"
fi
if printf '%s' "$NANO_IMAGE" | grep -q ':latest$'; then
  warn "Nano image uses 'latest'. For a release, pin a tested tag or sha256 digest."
fi
if [ "$EXASOL_PREBUILT" != "1" ] && [ "$JSON_TABLES_REF" = "main" ]; then
  warn "JSON Tables ref is 'main'. For a release, pin a tested tag or commit."
fi

cd "$INSTALL_DIR"

if [ "$EXASOL_PREBUILT" = "1" ]; then
  phase "Pulling & starting containers"
  info "Pulling prebuilt images - no local compile needed."
  docker compose --env-file .env -f "$COMPOSE_FILE" pull
  docker compose --env-file .env -f "$COMPOSE_FILE" up -d
else
  phase "Building & starting containers"
  info "First run pulls images and compiles the JSON Tables engine - this can take a few minutes."
  if [ "$SKIP_BUILD_TOOLS" = "1" ]; then
    docker compose --env-file .env -f "$COMPOSE_FILE" up -d --build nano mcp-server
  else
    docker compose --env-file .env -f "$COMPOSE_FILE" up -d --build
  fi
fi
ok "containers started"

phase "Finalizing"
cat > "$INSTALL_DIR/run-json-tables.sh" <<'EOF'
#!/usr/bin/env sh
set -eu
install_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$install_dir"
# Use whichever compose file this install was set up with.
if [ -f compose.release.yaml ]; then
  compose_file="compose.release.yaml"
else
  compose_file="compose.yaml"
fi
# json-tables runs as a standing container; exec the CLI into it.
exec docker compose --env-file .env -f "$compose_file" exec json-tables exasol-json-tables "$@"
EOF
chmod +x "$INSTALL_DIR/run-json-tables.sh"
ok "created run-json-tables.sh helper"
docker compose --env-file .env -f "$COMPOSE_FILE" ps
ok "health check complete"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
printf '  %s===================================================%s\n' "$C_GREEN" "$C_RST"
printf '   %s✓%s %sExasol AI is installed and running%s\n' "$C_GREEN" "$C_RST" "$C_WHT" "$C_RST"
printf '  %s===================================================%s\n' "$C_GREEN" "$C_RST"
printf '\n'
printf '   %sInstall dir%s %s\n' "$C_GRY" "$C_RST" "$INSTALL_DIR"
printf '   %sSQL        %s 127.0.0.1:%s\n' "$C_GRY" "$C_RST" "$SQL_PORT"
printf '   %sWeb UI     %s https://127.0.0.1:%s\n' "$C_GRY" "$C_RST" "$WEB_PORT"
printf '   %sMCP        %s http://127.0.0.1:%s/mcp\n' "$C_GRY" "$C_RST" "$MCP_PORT"
printf '\n'
printf '   %sNext steps%s\n' "$C_CYAN" "$C_RST"
printf '     - JSON Tables CLI : %s/run-json-tables.sh --help\n' "$INSTALL_DIR"
printf '     - Connect an MCP client to the MCP URL above\n'
printf '     - Uninstall       : %s/uninstall.sh\n' "$INSTALL_DIR"
printf '\n'
