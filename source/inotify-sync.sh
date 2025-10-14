#!/bin/bash

# CFS Data Migration - Parallel Full + Incremental Sync Script

set -euo pipefail

TARGET_HOST="${TARGET_HOST:?TARGET_HOST is required}"
SOURCE_PATH="${SOURCE_PATH:-/data}"
RSYNC_MODULE="${RSYNC_MODULE:-cfs}"
RSYNC_USER="${RSYNC_USER:-root}"
RSYNC_PORT="${RSYNC_PORT:-873}"
PASSWORD_FILE="/tmp/rsync.pass"
RSYNC_LOG="/var/log/rsync.log"
INOTIFY_LOG="/var/log/inotify.log"
INOTIFY_EVENTS="${INOTIFY_EVENTS:-modify,delete,create,attrib,move}"

echo "${RSYNC_PASSWORD}" > ${PASSWORD_FILE}
chmod 600 ${PASSWORD_FILE}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${RSYNC_LOG}
}

incremental_sync() {
    local changed_files="$1"
    rsync -avzP \
        --port=${RSYNC_PORT} \
        --timeout=100 \
        --delete \
        --password-file=${PASSWORD_FILE} \
        ${SOURCE_PATH}/ \
        ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
        >> ${RSYNC_LOG} 2>&1

    if [ $? -eq 0 ]; then
        log "Incremental synced: ${changed_files}"
    else
        log "ERROR: Incremental sync failed: ${changed_files}"
    fi
}

inotify_monitor() {
    log "=== Starting Inotify Real-time Monitoring ==="
    log "Monitoring events: ${INOTIFY_EVENTS}"
    inotifywait -mrq \
        --timefmt '%Y-%m-%d %H:%M:%S' \
        --format '%T %w%f %e' \
        -e ${INOTIFY_EVENTS} \
        ${SOURCE_PATH} | while read -r timestamp filepath events; do
            echo "${timestamp} ${filepath} ${events}" >> ${INOTIFY_LOG}
            incremental_sync "${filepath} (${events})"
    done
}

main() {
    log "=== CFS Migration Source - Starting ==="
    log "Configuration:"
    log "  Source Path: ${SOURCE_PATH}"
    log "  Target Host: ${TARGET_HOST}"
    log "  Rsync Module: ${RSYNC_MODULE}"
    log "  Rsync Port: ${RSYNC_PORT}"
    log "  Inotify Events: ${INOTIFY_EVENTS}"

    log "Testing connection to target..."
    if ! nc -zv ${TARGET_HOST} ${RSYNC_PORT} 2>&1 | tee -a ${RSYNC_LOG}; then
        log "WARNING: Cannot connect to target ${TARGET_HOST}:${RSYNC_PORT}"
        log "Will retry in sync process..."
    fi

    inotify_monitor &
    INOTIFY_PID=$!

    log "=== Starting Initial Full Sync ==="
    log "Source: ${SOURCE_PATH}"
    log "Target: ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE}"
    if rsync -avH \
        --port=${RSYNC_PORT} \
        --progress \
        --delete \
        --timeout=300 \
        --password-file=${PASSWORD_FILE} \
        ${SOURCE_PATH}/ \
        ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
        2>&1 | tee -a ${RSYNC_LOG}; then
        log "=== Initial Full Sync Completed Successfully ==="
    else
        log "ERROR: Initial sync failed!"
        kill ${INOTIFY_PID}
        exit 1
    fi

    wait ${INOTIFY_PID}
}

trap 'log "Received SIGTERM, shutting down..."; kill ${INOTIFY_PID} 2>/dev/null; exit 0' SIGTERM
trap 'log "Received SIGINT, shutting down..."; kill ${INOTIFY_PID} 2>/dev/null; exit 0' SIGINT

main
