#!/bin/bash
#
# Install restic backup systemd service and timer
# Run this script with: sudo bash /mnt/restic/install.sh
#

set -euo pipefail

echo "Installing restic backup systemd service and timer..."

# Copy systemd files
cp /mnt/restic/restic-backup.service /etc/systemd/system/
cp /mnt/restic/restic-backup.timer /etc/systemd/system/

# Create log file with proper permissions
touch /var/log/restic-backup.log
chmod 640 /var/log/restic-backup.log

# Reload systemd
systemctl daemon-reload

# Enable and start the timer
systemctl enable restic-backup.timer
systemctl start restic-backup.timer

echo
echo "Installation complete!"
echo
echo "Timer status:"
systemctl status restic-backup.timer --no-pager
echo
echo "Next scheduled run:"
systemctl list-timers restic-backup.timer --no-pager
