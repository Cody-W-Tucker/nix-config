# Automations Cookbook

Create systemd timers and services using native NixOS options.

## Pattern 1: Simple Scheduled Task (Recommended)

Use `startAt` for quick, one-off scheduled tasks:

```nix
# In your host.nix or any module
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
      User = "your-username";  # Or create a dedicated user
    };
    path = [ pkgs.rsync ];
    script = ''
      ${backupScript}/bin/backup-photos
    '';
    startAt = "daily";  # Creates timer automatically
  };
}
```

## Pattern 2: Long Script (Separate File)

For complex scripts, define them in a separate file:

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
      User = "root";  # Needs root for /var/log
    };
    path = [ pkgs.gzip pkgs.coreutils ];
    script = ''
      ${rotateScript}/bin/rotate-logs
    '';
    startAt = "weekly";
  };
}
```

## Pattern 3: Full Timer + Service (Advanced)

For complete control over timer and service:

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
  # Service definition
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

  # Separate timer definition
  systemd.timers.sync-data = {
    description = "Run sync-data every 4 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,04,08,12,16,20:00";
      Persistent = true;  # Catch up missed runs
      RandomizedDelaySec = "300";  # Add jitter
    };
  };
}
```

## Common Options

### `systemd.services.<name>`

| Option | Purpose | Example |
|--------|---------|---------|
| `description` | Human-readable description | `"Backup photos"` |
| `serviceConfig.Type` | Service type | `"oneshot"` for scripts |
| `serviceConfig.User` | Run as this user | `"myuser"` or `"root"` |
| `serviceConfig.WorkingDirectory` | Working directory | `"/var/lib/myapp"` |
| `path` | Packages available in PATH | `[ pkgs.curl pkgs.jq ]` |
| `environment` | Environment variables | `{ FOO = "bar"; }` |
| `script` | The script to execute | `''...''` |
| `startAt` | Schedule (creates timer) | `"daily"`, `"hourly"` |
| `preStart` | Run before main script | `''mkdir -p /var/data''` |
| `postStart` | Run after main script | `''notify-send "Done"''` |

### `systemd.timers.<name>` (when not using `startAt`)

| Option | Purpose | Example |
|--------|---------|---------|
| `timerConfig.OnCalendar` | When to run | `"*-*-* 03:00"` |
| `timerConfig.Persistent` | Catch up missed runs | `true` (recommended) |
| `timerConfig.RandomizedDelaySec` | Add jitter | `"600"` (10 min) |

## Frequency Examples

| Value | Runs |
|-------|------|
| `daily` | Every midnight |
| `hourly` | Every hour |
| `weekly` | Mondays at midnight |
| `monthly` | 1st of month at midnight |
| `Mon *-*-* 09:00` | Mondays at 9 AM |
| `*-*-* 00,12:00` | Twice daily at midnight and noon |
| `*-*-* *:00` | Every hour on the hour |

See `man systemd.time` for full syntax.

## Operations

```bash
# List all timers and when they run next
systemctl list-timers

# Trigger manually
systemctl start <service-name>

# Check status
systemctl status <service-name>
systemctl status <service-name>.timer

# View logs
journalctl -u <service-name> -f

# Reset if rate limited (start-limit-hit)
systemctl reset-failed <service-name>
systemctl start <service-name>
```

## Organization Tips

```
modules/services/automations/
├── backup-photos/
│   ├── default.nix      # Service config
│   └── script.nix       # Script (if complex)
├── rotate-logs/
│   └── default.nix      # Simple inline script
└── AGENTS.md            # This file
```

Or define directly in host files for simple one-offs.

## Security Hardening (Optional)

For sensitive automations, add to `serviceConfig`:

```nix
serviceConfig = {
  Type = "oneshot";
  User = "automation-user";
  
  # Sandboxing
  NoNewPrivileges = true;
  PrivateTmp = true;
  ProtectHome = true;
  ProtectSystem = "strict";
  ReadWritePaths = [ "/var/lib/myapp" ];
};
```

## Quick Template

Copy-paste starter:

```nix
{ pkgs, ... }:

let
  myScript = pkgs.writeShellApplication {
    name = "my-task";
    runtimeInputs = [ ];
    text = ''
      set -euo pipefail
      echo "Running at $(date)"
      # Your logic here
    '';
  };
in
{
  systemd.services.my-task = {
    description = "Description here";
    serviceConfig = {
      Type = "oneshot";
      User = "your-username";
    };
    path = [ ];
    script = ''
      ${myScript}/bin/my-task
    '';
    startAt = "daily";
  };
}
```

## Rules

- Use `writeShellApplication` not `writeShellScriptBin` (gets better error handling)
- Always `set -euo pipefail` in scripts
- Use `startAt` for simple cases, full `systemd.timers` for complex schedules
- Create dedicated users for services that touch sensitive data
- Set `Persistent = true` for data-integrity tasks
