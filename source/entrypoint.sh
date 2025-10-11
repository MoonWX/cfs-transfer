#!/bin/bash
set -e

echo "=== CFS Migration Tool - Source Server ==="
echo "Starting at $(date)"

if [ -z "${TARGET_HOST}" ]; then
    echo "ERROR: TARGET_HOST is not set!"
    exit 1
fi

mkdir -p /var/log

echo "Configuration:"
echo "  Source Path: ${SOURCE_PATH:-/mnt}"
echo "  Target Host: ${TARGET_HOST}"
echo "  Rsync Module: ${RSYNC_MODULE:-cfs}"
echo "  Rsync Port: ${RSYNC_PORT:-873}"
echo "  Rsync User: ${RSYNC_USER:-root}"

# 等待一小段时间确保网络就绪
sleep 2

exec /scripts/inotify-sync.sh
