#!/bin/bash
set -e

echo "=== CFS Migration Tool - Target Server ==="
echo "Starting at $(date)"

echo "${RSYNC_USER}:${RSYNC_PASSWORD}" > /etc/rsync/rsync.pass
chmod 600 /etc/rsync/rsync.pass

envsubst < /etc/rsync/rsyncd.conf.template > /etc/rsyncd.conf

mkdir -p /data

echo "Configuration:"
echo "  User: ${RSYNC_USER}"
echo "  Data Path: /data"
echo "  Max Connections: ${MAX_CONNECTIONS}"
echo "  Log File: /var/log/rsyncd.log"

echo "Starting rsync daemon..."

cd /data
rsync --daemon --no-detach --config=/etc/rsyncd.conf --log-file=/var/log/rsyncd.log
