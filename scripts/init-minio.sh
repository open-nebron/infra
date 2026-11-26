#!/bin/sh
set -e
until mc alias set local "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do sleep 2; done
mc mb -p local/"$R2_BUCKET" || true
mc anonymous set download local/"$R2_BUCKET"/users || true
mc anonymous set download local/"$R2_BUCKET"/posts || true
mc anonymous set download local/"$R2_BUCKET"/stories || true
mc anonymous set download local/"$R2_BUCKET"/reels || true
echo "minio ready"
