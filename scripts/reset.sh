#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "[reset] Stopping and tearing down all containers and volumes..."
docker compose --profile infra --profile auth --profile core --profile chat --profile voice down -v

echo "[reset] Pruning unused docker images..."
docker image prune -f

echo "[reset] Cleaning local environment overrides..."
rm -f .env.local 2>/dev/null || true

echo "Reset complete. Run \`make up-all\` to rebuild."
