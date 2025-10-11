#!/bin/bash

# CFS Data Migration - Inotify Sync Script
# This script monitors source directory and syncs changes to target in real-time

set -euo pipefail

TARGET_HOST="${TARGET_HOST:?TARGET_HOST is required}"
SOURCE_PATH="${SOURCE_PATH:-/mnt}"
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

initial_sync() {
    log "=== Starting Initial Full Sync ==="
    log "Source: ${SOURCE_PATH}"
    log "Target: ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE}"
    
    if rsync -avH \
        --port=${RSYNC_PORT} \
        --progress \
        --delete \
        --timeout=300 \
        --password-file=${PASSWORD_FILE} \
        /data/ \
        ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
        2>&1 | tee -a ${RSYNC_LOG}; then
        log "=== Initial Full Sync Completed Successfully ==="
        return 0
    else
        log "ERROR: Initial sync failed!"
        return 1
    fi
}

incremental_sync() {
    local changed_files="$1"
    
    rsync -avzP \
        --port=${RSYNC_PORT} \
        --timeout=100 \
        --delete \
        --password-file=${PASSWORD_FILE} \
        /data/\
        ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
        >> ${RSYNC_LOG} 2>&1
    
    if [ $? -eq 0 ]; then
        log "Synced: ${changed_files}"
    else
        log "ERROR: Failed to sync: ${changed_files}"
    fi
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
    
    retry_count=0
    max_retries=5
    while [ $retry_count -lt $max_retries ]; do
        if initial_sync; then
            break
        else
            retry_count=$((retry_count + 1))
            log "Retry $retry_count/$max_retries in 10 seconds..."
            sleep 10
        fi
    done
    
    if [ $retry_count -eq $max_retries ]; then
        log "ERROR: Initial sync failed after $max_retries attempts"
        exit 1
    fi
    
    log "=== Starting Real-time Monitoring ==="
    log "Monitoring events: ${INOTIFY_EVENTS}"
    
    inotifywait -mrq \
        --timefmt '%Y-%m-%d %H:%M:%S' \
        --format '%T %w%f %e' \
        -e ${INOTIFY_EVENTS} \
        /data | while read -r timestamp filepath events; do
        
        echo "${timestamp} ${filepath} ${events}" >> ${INOTIFY_LOG}
        
        incremental_sync "${filepath} (${events})"
    done
}

trap 'log "Received SIGTERM, shutting down..."; exit 0' SIGTERM
trap 'log "Received SIGINT, shutting down..."; exit 0' SIGINT

main
