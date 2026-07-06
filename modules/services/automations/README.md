# Automations

This directory contains reusable NixOS modules for scheduled jobs and system automations. Simple one-host tasks can also be defined directly in a host module.

## Layout

```text
modules/services/automations/
├── backup-photos/
│   ├── default.nix      # service and timer config
│   └── script.nix       # script package, when complex
├── rotate-logs/
│   └── default.nix      # inline script for a small task
├── AGENTS.md            # editor guidance
└── README.md            # operator reference
```

## Pattern: simple scheduled task

Use `startAt` when the service schedule is simple. NixOS creates the matching timer.

```nix
{ pkgs, ... }:

let
  backupScript = pkgs.writeShellApplication {
    name = "backup-photos";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      set -euo pipefail
      echo "Backing up photos at $(date)"
      rsync -av ~/Photos/ /mnt/backup/photos/
    '';
  };
in
{
  systemd.services.backup-photos = {
    description = "Backup photos to NAS";
    serviceConfig = {
      Type = "oneshot";
      User = "your-username";
    };
    path = [ pkgs.rsync ];
    script = ''
      ${backupScript}/bin/backup-photos
    '';
    startAt = "daily";
  };
}
```

## Pattern: longer script in a separate file

```nix
# modules/services/automations/rotate-logs/script.nix
{ pkgs }:

pkgs.writeShellApplication {
  name = "rotate-logs";
  runtimeInputs = [ pkgs.gzip pkgs.coreutils ];
  text = ''
    set -euo pipefail

    LOG_DIR="/var/log"
    ARCHIVE_DIR="/var/log/archive"

    mkdir -p "$ARCHIVE_DIR"

    for log in "$LOG_DIR"/*.log; do
      [ -f "$log" ] || continue

      size=$(stat -c%s "$log")
      if [ "$size" -gt 104857600 ]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        gzip -c "$log" > "$ARCHIVE_DIR/$(basename "$log").$timestamp.gz"
        truncate -s 0 "$log"
      fi
    done

    find "$ARCHIVE_DIR" -name "*.gz" -mtime +30 -delete
  '';
}
```

```nix
# modules/services/automations/rotate-logs/default.nix
{ pkgs, ... }:

let
  rotateScript = import ./script.nix { inherit pkgs; };
in
{
  systemd.services.rotate-logs = {
    description = "Rotate and compress large log files";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.gzip pkgs.coreutils ];
    script = ''
      ${rotateScript}/bin/rotate-logs
    '';
    startAt = "weekly";
  };
}
```

## Pattern: explicit timer and service

Use a separate timer for schedules that need catch-up, jitter, or more control.

```nix
{ pkgs, ... }:

let
  syncScript = pkgs.writeShellApplication {
    name = "sync-data";
    runtimeInputs = [ pkgs.rclone ];
    text = ''
      set -euo pipefail
      rclone sync /home/user/data remote:backup
    '';
  };
in
{
  systemd.services.sync-data = {
    description = "Sync data to cloud storage";
    serviceConfig = {
      Type = "oneshot";
      User = "your-username";
      WorkingDirectory = "/home/your-username";
    };
    path = [ pkgs.rclone ];
    environment = {
      RCLONE_CONFIG = "/home/your-username/.config/rclone/rclone.conf";
    };
    script = ''
      ${syncScript}/bin/sync-data
    '';
  };

  systemd.timers.sync-data = {
    description = "Run sync-data every 4 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,04,08,12,16,20:00";
      Persistent = true;
      RandomizedDelaySec = "300";
    };
  };
}
```

## Common options

### `systemd.services.<name>`

| Option | Purpose | Example |
| --- | --- | --- |
| `description` | Human-readable description | `"Backup photos"` |
| `serviceConfig.Type` | Service type | `"oneshot"` |
| `serviceConfig.User` | Run as this user | `"myuser"` or `"root"` |
| `serviceConfig.WorkingDirectory` | Working directory | `"/var/lib/myapp"` |
| `path` | Packages available in PATH | `[ pkgs.curl pkgs.jq ]` |
| `environment` | Environment variables | `{ FOO = "bar"; }` |
| `script` | Script to execute | `''...''` |
| `startAt` | Schedule that creates a timer | `"daily"`, `"hourly"` |
| `preStart` | Run before main script | `''mkdir -p /var/data''` |
| `postStart` | Run after main script | `''notify-send "Done"''` |

### `systemd.timers.<name>`

| Option | Purpose | Example |
| --- | --- | --- |
| `timerConfig.OnCalendar` | When to run | `"*-*-* 03:00"` |
| `timerConfig.Persistent` | Catch up missed runs | `true` |
| `timerConfig.RandomizedDelaySec` | Add jitter | `"600"` |

## Frequency examples

| Value | Runs |
| --- | --- |
| `daily` | Every midnight |
| `hourly` | Every hour |
| `weekly` | Mondays at midnight |
| `monthly` | First day of month at midnight |
| `Mon *-*-* 09:00` | Mondays at 9 AM |
| `*-*-* 00,12:00` | Twice daily at midnight and noon |
| `*-*-* *:00` | Every hour on the hour |

See `man systemd.time` for full calendar syntax.

## Operations

```bash
# List timers and next run times
systemctl list-timers

# Trigger manually
systemctl start <service-name>

# Check status
systemctl status <service-name>
systemctl status <service-name>.timer

# View logs
journalctl -u <service-name> -f

# Reset after start-limit-hit
systemctl reset-failed <service-name>
systemctl start <service-name>
```

## Hardening example

```nix
serviceConfig = {
  Type = "oneshot";
  User = "automation-user";
  NoNewPrivileges = true;
  PrivateTmp = true;
  ProtectHome = true;
  ProtectSystem = "strict";
  ReadWritePaths = [ "/var/lib/myapp" ];
};
```
