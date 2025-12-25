#!/bin/bash
#
# Restic backup script for /mnt (excluding /mnt/restic)
# Runs daily at 2:00 AM via systemd timer
#

set -euo pipefail

# Configuration
RESTIC_CONFIG="/mnt/restic/.restic-r2-env"
EXCLUDE_FILE="/mnt/restic/exclude.txt"
BACKUP_PATH="/mnt"
LOG_FILE="/var/log/restic-backup.log"

# Load credentials
if [[ ! -f "$RESTIC_CONFIG" ]]; then
    echo "ERROR: Config file not found: $RESTIC_CONFIG" >&2
    exit 1
fi
source "$RESTIC_CONFIG"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Restic Backup Started ==="

# Check if repository is accessible
log "Checking repository connectivity..."
if ! restic cat config &>/dev/null; then
    log "ERROR: Cannot connect to repository. Check credentials and network."
    exit 1
fi

# Perform backup
log "Starting backup of $BACKUP_PATH..."
if restic backup "$BACKUP_PATH" \
    --exclude-file="$EXCLUDE_FILE" \
    --verbose=1 \
    --tag automated \
    2>&1 | tee -a "$LOG_FILE"; then
    log "Backup completed successfully"
else
    log "ERROR: Backup failed with exit code $?"
    exit 1
fi

# Apply retention policy
log "Applying retention policy..."
if restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
    --tag automated \
    --prune \
    --verbose=1 \
    2>&1 | tee -a "$LOG_FILE"; then
    log "Retention policy applied successfully"
else
    log "WARNING: Retention policy failed with exit code $?"
fi

# Check repository integrity (weekly - only on Sundays)
if [[ $(date +%u) -eq 7 ]]; then
    log "Running weekly repository check..."
    if restic check --read-data-subset=5% 2>&1 | tee -a "$LOG_FILE"; then
        log "Repository check passed"
    else
        log "WARNING: Repository check failed"
    fi
fi

# Show backup statistics
log "Latest snapshot info:"
restic snapshots --latest 1 --tag automated 2>&1 | tee -a "$LOG_FILE"

log "=== Restic Backup Completed ==="
