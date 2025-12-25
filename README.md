# Restic Backup to Cloudflare R2

Complete automated backup solution for `/mnt` directory to Cloudflare R2 object storage using restic.

## Overview

This setup provides:
- **Automated daily backups** at 2:00 AM
- **Intelligent retention policy** (7 daily, 4 weekly, 6 monthly, 2 yearly)
- **Weekly integrity checks** to ensure backup health
- **Easy status monitoring** with a simple command
- **Secure encryption** with restic
- **Efficient storage** with deduplication

## Directory Structure

```
/mnt/restic/
├── README.md                  # This file
├── .restic-r2-env            # Credentials (keep secure!)
├── exclude.txt               # Files/folders to exclude from backup
├── backup.sh                 # Main backup script
├── status.sh                 # Status checker
├── install.sh                # Systemd installation script
├── restic-backup.service     # Systemd service definition
└── restic-backup.timer       # Systemd timer definition
```

## Prerequisites

- [x] Restic installed (version 0.18.1+)
- [x] Cloudflare account with R2 enabled
- [x] R2 bucket created
- [x] R2 API credentials (Access Key ID + Secret Access Key)

## Initial Setup

### Step 1: Configure Credentials

Edit `/mnt/restic/.restic-r2-env` and fill in your details:

```bash
nano /mnt/restic/.restic-r2-env
```

Replace the following values:
- `YOUR_R2_ACCESS_KEY_ID` - Your R2 Access Key ID
- `YOUR_R2_SECRET_ACCESS_KEY` - Your R2 Secret Access Key
- `YOUR_SECURE_RESTIC_PASSWORD` - A strong password for restic encryption
- `YOUR_ACCOUNT_ID` - Your Cloudflare Account ID
- `YOUR_BUCKET_NAME` - Your R2 bucket name

**Important:** Keep this file secure! It contains sensitive credentials.

```bash
chmod 600 /mnt/restic/.restic-r2-env
```

### Step 2: Initialize Restic Repository

First-time setup only:

```bash
source /mnt/restic/.restic-r2-env
restic init
```

You should see: `created restic repository [ID] at s3:https://...`

### Step 3: Install Systemd Service

Install the automated backup service:

```bash
sudo bash /mnt/restic/install.sh
```

This will:
- Copy systemd service and timer files
- Create log file
- Enable and start the timer
- Show the next scheduled backup time

## Usage

### Check Backup Status

Run anytime to see backup health and recent snapshots:

```bash
/mnt/restic/status.sh
```

**Output includes:**
- Repository connectivity status
- 5 most recent snapshots
- Repository statistics (size, files, etc.)
- Last backup time from logs
- Warning if no backup in last 26 hours

### Manual Backup

Run a backup manually (outside of scheduled time):

```bash
/mnt/restic/backup.sh
```

The script will:
1. Check repository connectivity
2. Backup `/mnt` (excluding `/mnt/restic`)
3. Apply retention policy
4. Run integrity check if it's Sunday
5. Log everything to `/var/log/restic-backup.log`

### View Snapshots

List all backups:

```bash
source /mnt/restic/.restic-r2-env
restic snapshots
```

List only recent backups:

```bash
source /mnt/restic/.restic-r2-env
restic snapshots --latest 10
```

### Restore Files

Restore entire latest snapshot:

```bash
source /mnt/restic/.restic-r2-env
restic restore latest --target /path/to/restore/location
```

Restore specific snapshot by ID:

```bash
source /mnt/restic/.restic-r2-env
restic snapshots  # Find snapshot ID
restic restore abc12345 --target /path/to/restore/location
```

Restore specific files/folders:

```bash
source /mnt/restic/.restic-r2-env
restic restore latest --target /tmp/restore --include /mnt/important/file.txt
```

### Search for Files

Find a file in backups:

```bash
source /mnt/restic/.restic-r2-env
restic find "filename.txt"
```

### Compare Snapshots

See what changed between snapshots:

```bash
source /mnt/restic/.restic-r2-env
restic diff snapshot1_id snapshot2_id
```

## Retention Policy

The backup script automatically maintains these snapshots:

| Type    | Kept | Example                           |
|---------|------|-----------------------------------|
| Daily   | 7    | Last 7 days                       |
| Weekly  | 4    | Last 4 weeks                      |
| Monthly | 6    | Last 6 months                     |
| Yearly  | 2    | Last 2 years                      |

**How it works:**
- After each backup, old snapshots are automatically deleted
- Only snapshots tagged as "automated" are affected
- Manually created snapshots are preserved
- Deleted snapshots are pruned to reclaim storage space

**To modify retention policy**, edit `/mnt/restic/backup.sh` and change:

```bash
restic forget \
    --keep-daily 7 \    # Change these values
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
```

## Systemd Management

### Check Timer Status

See when next backup will run:

```bash
systemctl status restic-backup.timer
```

or

```bash
systemctl list-timers restic-backup.timer
```

### View Backup Logs

Real-time log viewing:

```bash
journalctl -u restic-backup.service -f
```

View recent logs:

```bash
journalctl -u restic-backup.service -n 100
```

View logs from specific date:

```bash
journalctl -u restic-backup.service --since "2025-12-20"
```

### Manual Service Control

Run backup service manually:

```bash
sudo systemctl start restic-backup.service
```

Stop the timer (disable automatic backups):

```bash
sudo systemctl stop restic-backup.timer
```

Disable automatic backups permanently:

```bash
sudo systemctl disable restic-backup.timer
```

Re-enable automatic backups:

```bash
sudo systemctl enable restic-backup.timer
sudo systemctl start restic-backup.timer
```

## Exclude Patterns

The `/mnt/restic/exclude.txt` file controls what gets excluded from backups.

**Current exclusions:**
- `/mnt/restic` - The backup scripts and credentials

**Common patterns to add:**

```bash
# Cache directories
**/.cache
**/cache
**/Cache

# Temporary files
**/tmp
**/temp
**/*.tmp

# System files
**/.Trash-*
**/lost+found

# Development
**/node_modules
**/.git
**/__pycache__

# Media cache
**/.thumbnails
**/Thumbs.db

# Logs
**/*.log
**/logs
```

**Syntax:**
- `/absolute/path` - Exclude exact path
- `**/pattern` - Exclude pattern in any directory
- `*.ext` - Exclude by extension
- Lines starting with `#` are comments

After modifying excludes, run a manual backup to apply changes.

## Monitoring & Maintenance

### Health Checks

The backup script automatically:
- Checks repository connectivity before each backup
- Runs integrity check every Sunday (5% data verification)
- Logs all operations to `/var/log/restic-backup.log`

### Manual Repository Check

Full repository verification:

```bash
source /mnt/restic/.restic-r2-env
restic check --read-data
```

**Warning:** Full check reads all data and may incur R2 egress costs.

Quick check (metadata only):

```bash
source /mnt/restic/.restic-r2-env
restic check
```

### Prune Unused Data

Remove unreferenced data to reclaim space:

```bash
source /mnt/restic/.restic-r2-env
restic prune
```

**Note:** The backup script runs `--prune` automatically with `forget`, so manual pruning is rarely needed.

### Monitor Storage Usage

Check repository statistics:

```bash
source /mnt/restic/.restic-r2-env
restic stats
```

Detailed breakdown by file type:

```bash
source /mnt/restic/.restic-r2-env
restic stats --mode raw-data
```

## Troubleshooting

### Backup Failed - Connection Error

**Problem:** Cannot connect to R2 repository

**Solutions:**
1. Check internet connectivity: `ping 1.1.1.1`
2. Verify credentials in `/mnt/restic/.restic-r2-env`
3. Test R2 access: `source /mnt/restic/.restic-r2-env && restic snapshots`
4. Check Cloudflare R2 status

### Backup Failed - Permission Denied

**Problem:** Cannot read certain files in `/mnt`

**Solutions:**
1. Ensure backup script runs as root (check systemd service)
2. Verify `/mnt` is accessible: `ls -la /mnt`
3. Add problematic paths to `exclude.txt` if they're not needed

### Timer Not Running

**Problem:** Backups not running at scheduled time

**Solutions:**
1. Check timer is enabled: `systemctl is-enabled restic-backup.timer`
2. Check timer is active: `systemctl is-active restic-backup.timer`
3. View timer status: `systemctl status restic-backup.timer`
4. Check system time is correct: `timedatectl`

### Repository Locked

**Problem:** Error: repository is already locked

**Solutions:**
1. Check if backup is currently running: `ps aux | grep restic`
2. Unlock if backup crashed: `source /mnt/restic/.restic-r2-env && restic unlock`

### High Storage Usage

**Problem:** R2 storage costs higher than expected

**Solutions:**
1. Review retention policy (reduce kept snapshots)
2. Check for large files: `restic stats --mode files-by-contents`
3. Add excludes for large unnecessary files
4. Run prune to remove unused data: `restic prune`

## Security Best Practices

1. **Protect credentials:**
   ```bash
   chmod 600 /mnt/restic/.restic-r2-env
   ```

2. **Use strong restic password:**
   - Minimum 16 characters
   - Mix of letters, numbers, symbols
   - Store securely (password manager)

3. **Backup your restic password:**
   - Without it, backups are **unrecoverable**
   - Store in separate secure location

4. **Limit R2 API token permissions:**
   - Use "Object Read & Write" only
   - Scope to specific bucket if possible

5. **Regular verification:**
   - Check backups monthly: `restic check`
   - Test restores periodically

## Cost Optimization

**Cloudflare R2 Pricing (as of 2025):**
- Storage: $0.015/GB/month
- Class A operations (write): $4.50 per million requests
- Class B operations (read): $0.36 per million requests
- **No egress fees** (major advantage over S3)

**Tips to reduce costs:**
1. Adjust retention policy to keep fewer snapshots
2. Exclude unnecessary large files (cache, temp files)
3. Use `restic prune` to remove unused data
4. Monitor with `restic stats`

## Advanced Usage

### Browse Snapshots

Mount backup as filesystem to browse files:

```bash
source /mnt/restic/.restic-r2-env
mkdir /tmp/restic-mount
restic mount /tmp/restic-mount
# Browse files, then unmount:
umount /tmp/restic-mount
```

### Backup to Multiple Destinations

Create second repository (e.g., local backup):

```bash
export RESTIC_REPOSITORY="/mnt/local-backup"
export RESTIC_PASSWORD="different-password"
restic init
restic backup /mnt --exclude-file=/mnt/restic/exclude.txt
```

### Change Backup Schedule

Edit timer to run at different time:

```bash
sudo nano /etc/systemd/system/restic-backup.timer
```

Change `OnCalendar=*-*-* 02:00:00` to desired time, then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart restic-backup.timer
```

**Examples:**
- `OnCalendar=*-*-* 03:30:00` - Daily at 3:30 AM
- `OnCalendar=Mon *-*-* 02:00:00` - Mondays at 2:00 AM
- `OnCalendar=*-*-1 02:00:00` - First day of month at 2:00 AM

## Quick Reference

### Essential Commands

```bash
# Check status
/mnt/restic/status.sh

# Manual backup
/mnt/restic/backup.sh

# List backups
source /mnt/restic/.restic-r2-env && restic snapshots

# Restore latest
source /mnt/restic/.restic-r2-env && restic restore latest --target /restore

# Find file
source /mnt/restic/.restic-r2-env && restic find "filename"

# Check health
source /mnt/restic/.restic-r2-env && restic check

# Timer status
systemctl status restic-backup.timer

# View logs
journalctl -u restic-backup.service -n 50
```

## Getting Help

- Restic documentation: https://restic.readthedocs.io/
- Restic forum: https://forum.restic.net/
- Cloudflare R2 docs: https://developers.cloudflare.com/r2/

## Backup the Backup

**Critical reminder:** Your backups are only as good as your ability to restore them!

1. **Store restic password separately** - Without it, backups are useless
2. **Test restores regularly** - Verify you can actually recover data
3. **Document your setup** - Keep notes on your configuration
4. **Monitor backup health** - Run `/mnt/restic/status.sh` weekly

---

**Setup Date:** 2025-12-24
**Restic Version:** 0.18.1
**Backup Path:** /mnt (excluding /mnt/restic)
**Schedule:** Daily at 2:00 AM
**Retention:** 7 daily, 4 weekly, 6 monthly, 2 yearly
