#!/bin/bash
#
# Restic backup status checker
# Shows recent backup information and health status
#

set -euo pipefail

# Configuration
RESTIC_CONFIG="/mnt/restic/.restic-r2-env"
LOG_FILE="/var/log/restic-backup.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load credentials
if [[ ! -f "$RESTIC_CONFIG" ]]; then
    echo -e "${RED}ERROR: Config file not found: $RESTIC_CONFIG${NC}" >&2
    exit 1
fi
source "$RESTIC_CONFIG"

echo "=== Restic Backup Status ==="
echo

# Check repository connectivity
echo -n "Repository connectivity: "
if restic cat config &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    exit 1
fi

# Show latest snapshots
echo
echo "Latest snapshots:"
restic snapshots --latest 5 --compact

# Show repository statistics
echo
echo "Repository statistics:"
restic stats --mode raw-data

# Check last backup time from log
if [[ -f "$LOG_FILE" ]]; then
    echo
    echo "Last backup log entries:"
    grep "Backup Started\|Backup Completed" "$LOG_FILE" | tail -4

    # Check if backup ran in last 26 hours (allowing 2-hour window)
    if [[ -n $(find "$LOG_FILE" -mmin -1560 2>/dev/null) ]]; then
        echo
        echo -e "Last backup status: ${GREEN}Recent (within 26 hours)${NC}"
    else
        echo
        echo -e "Last backup status: ${YELLOW}WARNING: No backup in last 26 hours${NC}"
    fi
else
    echo
    echo -e "${YELLOW}WARNING: No log file found at $LOG_FILE${NC}"
fi
