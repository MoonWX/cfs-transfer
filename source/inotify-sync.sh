#!/bin/bash

# CFS Data Migration - True Parallel Full + Incremental Sync Script

set -euo pipefail

TARGET_HOST="${TARGET_HOST:?TARGET_HOST is required}"
RSYNC_MODULE="${RSYNC_MODULE:-cfs}"
RSYNC_USER="${RSYNC_USER:-root}"
RSYNC_PORT="${RSYNC_PORT:-873}"
PASSWORD_FILE="/tmp/rsync.pass"
RSYNC_LOG="/var/log/rsync.log"
INOTIFY_LOG="/var/log/inotify.log"
INOTIFY_EVENTS="${INOTIFY_EVENTS:-modify,delete,create,attrib,move}"
INCREMENTAL_QUEUE="/tmp/rsync_queue.txt"
FULL_SYNC_LOCK="/tmp/full_sync.lock"

echo "${RSYNC_PASSWORD}" > ${PASSWORD_FILE}
chmod 600 ${PASSWORD_FILE}

# 创建队列文件
touch ${INCREMENTAL_QUEUE}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a ${RSYNC_LOG}
}

incremental_sync_worker() {
    log "=== Incremental Sync Worker Started ==="
    
    while true; do
        if [ -s ${INCREMENTAL_QUEUE} ]; then
            local batch
            batch=$(cat ${INCREMENTAL_QUEUE})
            > ${INCREMENTAL_QUEUE}
            
            log "Processing incremental batch ($(echo "$batch" | wc -l) changes)"
            
            rsync -avzP \
                --port=${RSYNC_PORT} \
                --timeout=100 \
                --delete \
                --password-file=${PASSWORD_FILE} \
                --relative \
                /data/./ \
                ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
                >> ${RSYNC_LOG} 2>&1
            
            if [ $? -eq 0 ]; then
                log "Incremental sync completed successfully"
            else
                log "ERROR: Incremental sync failed"
            fi
        fi
        
        sleep 2
    done
}

inotify_monitor() {
    log "=== Starting Inotify Real-time Monitoring ==="
    log "Monitoring events: ${INOTIFY_EVENTS}"
    
    inotifywait -mrq \
        --timefmt '%Y-%m-%d %H:%M:%S' \
        --format '%T %w%f %e' \
        -e ${INOTIFY_EVENTS} \
        /data | while read -r timestamp filepath events; do
            echo "${timestamp} ${filepath} ${events}" >> ${INOTIFY_LOG}
            echo "${filepath}" >> ${INCREMENTAL_QUEUE}  # 加入队列
    done
}

full_sync() {
    log "=== Starting Initial Full Sync ==="
    # log "Source: ${SOURCE_PATH}"
    log "Target: ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE}"
    
    touch ${FULL_SYNC_LOCK}
    
    if rsync -avH \
        --port=${RSYNC_PORT} \
        --progress \
        --delete \
        --timeout=300 \
        --password-file=${PASSWORD_FILE} \
        --relative \
        /data/./ \
        ${RSYNC_USER}@${TARGET_HOST}::${RSYNC_MODULE} \
        2>&1 | tee -a ${RSYNC_LOG}; then
        log "=== Initial Full Sync Completed Successfully ==="
        rm -f ${FULL_SYNC_LOCK}
        return 0
    else
        log "ERROR: Initial full sync failed!"
        rm -f ${FULL_SYNC_LOCK}
        return 1
    fi
}

cleanup() {
    log "Shutting down gracefully..."
    kill ${INOTIFY_PID} 2>/dev/null || true
    kill ${WORKER_PID} 2>/dev/null || true
    rm -f ${PASSWORD_FILE} ${FULL_SYNC_LOCK}
    exit 0
}

main() {
    log "=== CFS Migration Source - Starting Parallel Mode ==="
    log "Configuration:"
    # log "  Source Path: ${SOURCE_PATH}"
    log "  Target Host: ${TARGET_HOST}"
    log "  Rsync Module: ${RSYNC_MODULE}"
    log "  Rsync Port: ${RSYNC_PORT}"
    log "  Inotify Events: ${INOTIFY_EVENTS}"

    log "Testing connection to target..."
    if ! nc -zv ${TARGET_HOST} ${RSYNC_PORT} 2>&1 | tee -a ${RSYNC_LOG}; then
        log "WARNING: Cannot connect to target ${TARGET_HOST}:${RSYNC_PORT}"
        log "Will retry in sync process..."
    fi

    incremental_sync_worker &
    WORKER_PID=$!
    log "Incremental sync worker started (PID: ${WORKER_PID})"

    inotify_monitor &
    INOTIFY_PID=$!
    log "Inotify monitor started (PID: ${INOTIFY_PID})"

    sleep 2

    if ! full_sync; then
        cleanup
        exit 1
    fi

    log "=== All processes running, monitoring continues ==="
    
    wait ${INOTIFY_PID}
}

trap cleanup SIGTERM SIGINT

main
