#!/usr/bin/env sh
set -eu

INSTALL_DIR="${INSTALL_DIR:-"$HOME/.exasol-ai"}"
REMOVE_DATA="${REMOVE_DATA:-0}"

if [ ! -d "$INSTALL_DIR" ]; then
  printf 'Install directory not found: %s\n' "$INSTALL_DIR"
  exit 0
fi

if [ -f "$INSTALL_DIR/compose.yaml" ]; then
  cd "$INSTALL_DIR"
  if [ "$REMOVE_DATA" = "1" ]; then
    docker compose --env-file .env -f compose.yaml down --volumes
  else
    docker compose --env-file .env -f compose.yaml down
  fi
fi

rm -rf "$INSTALL_DIR"

if [ "$REMOVE_DATA" = "1" ]; then
  printf 'Exasol AI MVP removed, including Docker volume data.\n'
else
  printf 'Exasol AI MVP removed. Docker volume data was preserved.\n'
  printf 'Run with REMOVE_DATA=1 to remove persisted Nano data.\n'
fi
