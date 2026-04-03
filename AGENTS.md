# CodyOS

You are assisting a user working on a modern NixOS system config using flakes.

Here's a overview on common patterns and practices you'll help with.

## Build Testing

You don't have access to the `sudo` command. `sudo` is required to effect a system rebuild.

These build commands are for testing if the build will actually work. If you're unsure whether the config change will build properly you may use the proper build command.

```bash
# Test build current host
nixos-rebuild dry-run --flake .

# Test build a different host. (Check the hostname of the current session if unsure.)
nixos-rebuild dry-run --flake .#beast

# Checks entire system and all flake outputs.
nix flake check
```

If the system doesn't build, check the logs and solve the issues.

Once the changes have settled, the user will run the `update` script to build and activate the system.

## Repo map

```text
.
├── hosts/              # Machine identity: boot, disks, hostname, networking, hardware-specific overrides, system.stateVersion
│   ├── aiserver.nix    # AI workstation configuration
│   ├── beast.nix       # Desktop workstation configuration
│   └── server.nix      # Media and homelab server configuration
├── modules/            # Reusable NixOS modules organized by purpose
│   ├── desktop/        # Desktop environment: WMs, compositors (Hyprland), printing, display settings
│   ├── server/         # Server services: one service per file (nginx, monitoring, media, etc)
│   ├── services/       # Shared services: Syncthing and other cross-host services
│   └── system/         # System-wide config: locale, users, networking, logging, shared packages
├── packages/           # Custom packages and scripts: internal CLI tools, patched packages
├── secrets/            # SOPS declarations and encrypted material
├── users/              # Home Manager configurations: shells, dev tools, dotfiles, home.stateVersion
│   ├── cody/           # User 'cody' configuration
│   │   ├── agent/      # AI agent tools (opencode, MCP configs)
│   │   ├── cli/        # CLI tools (nixvim, shell configs)
│   │   ├── packages/   # Custom user packages and scripts
│   │   └── ui/         # Desktop UI (Hyprland, rofi, waybar, notifications)
│   └── home.nix        # Shared home configuration entry point
└── wallpapers/         # Static assets
```

## High-value repo rules

### Naming & Files

- Use lowercase kebab-case for all file names
- Match upstream package names when practical; use CLI-safe kebab-case for internal scripts
- Use quoted attribute names for secret keys with dashes: `sops.secrets."paperless-password"`

### Module Structure

- Naming: `modules/{location}/{item}/default.nix` and file.
- Keep `default.nix` short.
  - Use supporting files with self-explaining names if needed.
  - Examples: `module.nix`, `package.nix` and `service.nix`.
- Keep secrets declarations close to their consuming service

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- Never commit raw secrets (use SOPS-NIX.)
  - The user will need to add secrets via the sops edit command.

## Systemd Service Operations

Tips for running persistent agent services and scheduled tasks:

### Timers and Scheduling

- Use `Type = "oneshot"` with paired `.timer` units for scheduled tasks
- **Always set `Persistent = true`** in timer configs
  - Without it, missed runs (during downtime) are skipped forever
  - With it, missed runs execute immediately on next boot

### Common Pitfalls

- **`start-limit-inhibited`**: Rapid restarts trigger systemd rate limiting
  - Check: `systemctl status <service>` shows "start-limit-hit"
  - Fix: `systemctl reset-failed <service>` then `systemctl start <service>`
- **Set `WorkingDirectory`** in all service configs to prevent path issues
- **Set `PATH` explicitly** if service calls external binaries (systemd doesn't inherit shell PATH)

## Observability & Tracing

- The monitoring host now runs `Grafana`, `Loki`, `Tempo`, and `OpenTelemetry Collector` in `modules/server/monitoring.nix`
- `update` emits `nixos.rebuild` traces and `pull-update` emits `nixos.pull_update` traces with service name `codyos-update`
- Trace health spans include failed unit count and recent error-log deltas after `nixos-rebuild switch`
- Use the Grafana API or MCP to discover current datasource UIDs before querying; legacy Grafana DB state may differ from repo intent
- If Grafana MCP calls return `502`, check `grafana.service`, `tempo.service`, and `opentelemetry-collector.service` on `server` first

## Requirements:

- Keep this file updated using these rules.
  - If you learn something new about the system or if something changes
  - it would be helpful to see every time.
