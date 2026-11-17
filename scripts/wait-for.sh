#!/usr/bin/env bash
set -e

URL="$1"
TIMEOUT="${2:-60}"

if [ -z "$URL" ]; then
  echo "Usage: $0 <url> [timeout_seconds]"
  exit 1
fi

echo "[wait-for] Waiting for $URL (timeout: ${TIMEOUT}s)..."

START_TIME=$(date +%s)
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || true)
  if [ "$STATUS" = "200" ]; then
    echo "[wait-for] ✓ $URL is healthy (HTTP 200)"
    exit 0
  fi

  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "[wait-for] ✗ Timed out waiting for $URL after ${TIMEOUT}s (last HTTP status: ${STATUS:-unreachable})"
    exit 1
  fi

  sleep 1
done
