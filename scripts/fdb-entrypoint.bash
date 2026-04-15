#!/bin/bash

# fdb-entrypoint.bash
#
# Wraps the official FoundationDB Docker entrypoint to handle first-boot
# database initialization. The official image starts fdbserver but never
# runs "configure new single ssd", so clients get "database unavailable"
# until someone does that manually. This script does it automatically.

set -euo pipefail

CLUSTER_FILE_DIR="/var/fdb/cluster"
CLUSTER_FILE="${CLUSTER_FILE_DIR}/fdb.cluster"
FDB_PORT="${FDB_PORT:-4500}"

cluster_description="docker:docker@127.0.0.1:${FDB_PORT}"

# Write cluster file to the shared volume so other containers (and the
# host, via a bind mount) can discover the coordinator.
mkdir -p "${CLUSTER_FILE_DIR}"
echo "${cluster_description}" > "${CLUSTER_FILE}"

# Also tell the official entrypoint what cluster string to use.
export FDB_CLUSTER_FILE_CONTENTS="${cluster_description}"

echo "Cluster file: ${cluster_description}"

# Background process: wait for fdbserver to accept connections, then
# configure the database exactly once. "configure new" is idempotent in
# the sense that it errors harmlessly if the database already exists.
(
    echo "Waiting for fdbserver to become reachable..."
    attempts=0
    max_attempts=30
    while [[ $attempts -lt $max_attempts ]]; do
        if fdbcli -C "${CLUSTER_FILE}" --exec "status minimal" &>/dev/null; then
            break
        fi
        attempts=$((attempts + 1))
        sleep 1
    done

    if [[ $attempts -ge $max_attempts ]]; then
        echo "ERROR: fdbserver did not become reachable after ${max_attempts}s" >&2
        exit 1
    fi

    # "configure new single ssd" fails with a clear error if the database
    # is already configured -- that's fine, we just swallow it.
    if fdbcli -C "${CLUSTER_FILE}" --exec "configure new single ssd" 2>/dev/null; then
        echo "Database configured: new single ssd"
    else
        echo "Database already configured (or configure failed -- check status)"
    fi

    # Final status check so the logs show something useful.
    fdbcli -C "${CLUSTER_FILE}" --exec "status minimal"
) &

# Hand off to the official entrypoint (fdb.bash -> fdbserver).
# Force host networking mode so the server advertises 127.0.0.1.
export FDB_NETWORKING_MODE=host
exec /var/fdb/scripts/fdb.bash
