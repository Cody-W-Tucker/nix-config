# Base System Configuration
Relevant source files
- [modules/server/actual-budget.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/actual-budget.nix)
- [modules/server/nginx-syncthing.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/nginx-syncthing.nix)
- [modules/services/syncthing.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/syncthing.nix)
- [modules/system/fonts.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/fonts.nix)
- [modules/system/locale.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/locale.nix)
- [modules/system/nix.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix)
- [modules/system/services.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix)
- [modules/system/shell.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/shell.nix)
- [modules/system/users.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix)

The base system configuration provides the foundational layer for all hosts in the CodyOS ecosystem. It establishes core environment settings, user identity, system-level services, and the integration points for secret management via `sops-nix` and user-level configuration via `home-manager`.

## Core Environment and Identity

The system identity is defined through locale settings and a centralized user management strategy.

### Locale and Time

System-wide time is set to `America/Chicago`[modules/system/locale.nix6](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/locale.nix#L6-L6) with `en_US.UTF-8` enforced across all `i18n` categories including `LC_MONETARY`, `LC_TIME`, and `LC_MEASUREMENT`[modules/system/locale.nix9-20](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/locale.nix#L9-L20)

### User Management

The primary user, `codyt`, is defined with `users.mutableUsers = false`[modules/system/users.nix7](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix#L7-L7) ensuring that the user environment is declaratively managed and resistant to manual modification. The user is assigned to critical system groups such as `wheel`, `docker`, and `networkmanager`, as well as custom groups like `media` and `documents`[modules/system/users.nix12-22](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix#L12-L22)

### Shell and Fonts

- **Shell**: `zsh` is the default system shell [modules/system/users.nix23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix#L23-L23) To prevent performance degradation caused by double-initialization of `compinit`, `enableCompletion` is explicitly disabled at the system level [modules/system/shell.nix16](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/shell.nix#L16-L16) deferring completion logic to the `home-manager` configuration.
- **Fonts**: The system provides a standard set of typography, including `JetBrainsMono Nerd Font` for development and `Noto Color Emoji` for UI elements [modules/system/fonts.nix9-16](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/fonts.nix#L9-L16)

## Nix Package Manager Configuration

The Nix configuration optimizes the build environment and handles private flake inputs through `sops-nix` templates.

### Automated Maintenance

The system performs weekly garbage collection, deleting generations older than 7 days [modules/system/nix.nix37-41](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix#L37-L41)`auto-optimise-store` is enabled to reduce disk usage via hard-linking identical store paths [modules/system/nix.nix23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix#L23-L23)

### Private Access and Templates

To allow Nix to fetch private repositories during evaluation, a `github-nix-secrets-read` secret is injected into a Nix configuration template [modules/system/nix.nix8-16](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix#L8-L16)

**Nix Secret Data Flow**

```

```

*Sources: [modules/system/nix.nix8-21](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix#L8-L21)*

## System Services and Maintenance

CodyOS utilizes several background services to maintain hardware health and system integrity.

| Service | Purpose | Implementation Detail |
| --- | --- | --- |
| `fwupd` | Firmware updates | `fwupd-refresh` is overridden to run as `root` to bypass interactive `polkit` prompts [modules/system/services.nix34-42](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L34-L42) |
| `logrotate` | Log management | Enabled system-wide to prevent disk exhaustion [modules/system/services.nix21](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L21-L21) |
| `smartctl-exporter` | Hardware Monitoring | Exports SMART data to Prometheus for disk health tracking [modules/system/services.nix26-31](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L26-L31) |
| `command-not-found` | UX / Discovery | Uses `flake-programs-sqlite` to suggest packages for missing commands [modules/system/services.nix12-17](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L12-L17) |

### Hardware and Firmware

The system is configured to allow non-free redistributable firmware, which is essential for Bluetooth and WiFi hardware support across different host types [modules/system/services.nix45](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L45-L45)

## Syncthing Integration

Syncthing is utilized for cross-host file synchronization, with specific folder paths determined by the host's identity.

**Syncthing Logic Flow**

```

```

*Sources: [modules/services/syncthing.nix33-55](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/syncthing.nix#L33-L55)*

## Secret and User Home Wiring

The system integrates `sops-nix` for secret management and `home-manager` for user-specific configurations. While `home-manager` handles the user's `$HOME` environment, the system configuration ensures that necessary directory structures exist via `systemd.tmpfiles.rules`. For example, specific directories for `borgbackup` and `syncthing` mounts are pre-created to avoid permission conflicts or warnings during service startup [modules/system/users.nix37-42](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix#L37-L42)[modules/services/syncthing.nix26-30](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/syncthing.nix#L26-L30)

*Sources: [modules/system/services.nix1-46](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/services.nix#L1-L46)[modules/system/users.nix1-43](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/users.nix#L1-L43)[modules/system/nix.nix1-43](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/nix.nix#L1-L43)[modules/services/syncthing.nix1-56](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/syncthing.nix#L1-L56)[modules/system/fonts.nix1-19](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/fonts.nix#L1-L19)[modules/system/locale.nix1-22](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/locale.nix#L1-L22)[modules/system/shell.nix1-20](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/shell.nix#L1-L20)*