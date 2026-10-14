#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(dirname -- "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd -P)"

LAB_DIR="${LAB_DIR:-$SCRIPT_DIR/xtrabackup-lab}"
BACKUP="${BACKUP:-$LAB_DIR/backup.xbs.gz.aes}"
WORK="${WORK:-$LAB_DIR/work/restore}"

PASSWORD="${PASSWORD:-password}"
XTRABACKUP_IMAGE="${XTRABACKUP_IMAGE:-percona/percona-xtrabackup:8.0}"

echo "Repository:     $SCRIPT_DIR"
echo "Lab directory:  $LAB_DIR"
echo "Backup:         $BACKUP"
echo "Work directory: $WORK"

if [ ! -f "$BACKUP" ]; then
    echo "Backup not found: $BACKUP" >&2
    exit 1
fi

case "$WORK" in
    "$LAB_DIR"/work/*)
        ;;
    *)
        echo "Unsafe WORK path: $WORK" >&2
        exit 1
        ;;
esac

rm -rf "$WORK"
mkdir -p "$WORK/backup-extracted"

echo "[1/5] AES decrypt"

openssl aes-256-cbc \
    -d \
    -pbkdf2 \
    -pass "pass:$PASSWORD" \
    -in "$BACKUP" \
    -out "$WORK/backup.xbs.gz"

echo "[2/5] Checking gzip"

gzip -t "$WORK/backup.xbs.gz"

echo "[3/5] Decompressing gzip"

gzip -dc "$WORK/backup.xbs.gz" \
    > "$WORK/backup.xbs"

echo "[4/5] Extracting xbstream"

ABS_WORK="$(cd "$WORK" && pwd -P)"

docker run --rm -i \
    --user 0:0 \
    -v "$ABS_WORK:/work" \
    --entrypoint xbstream \
    "$XTRABACKUP_IMAGE" \
    -x \
    -C /work/backup-extracted \
    < "$WORK/backup.xbs"

echo "[5/5] Preparing and exporting tablespaces"

docker run --rm \
    --user 0:0 \
    -v "$ABS_WORK:/work" \
    --entrypoint xtrabackup \
    "$XTRABACKUP_IMAGE" \
    --prepare \
    --export \
    --target-dir=/work/backup-extracted

echo
echo "Checkpoint:"
cat "$WORK/backup-extracted/xtrabackup_checkpoints"

echo
echo "Exported city files:"
ls -lh "$WORK/backup-extracted/world/city."*

echo
echo "Backup prepared successfully."
