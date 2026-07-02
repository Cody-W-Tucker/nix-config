# Hermes Package, Runtime, and Secrets
Relevant source files
- [modules/services/hermes-agent/AGENTS.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/AGENTS.md?plain=1)
- [modules/services/hermes-agent/mcp/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/mcp/default.nix)
- [modules/services/hermes-agent/package/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix)
- [modules/services/hermes-agent/package/patches/auth-store-group-access.patch](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/patches/auth-store-group-access.patch)
- [modules/services/hermes-agent/package/patches/hermes-home-group-access.patch](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/patches/hermes-home-group-access.patch)
- [modules/services/hermes-agent/runtime/cron-tick.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/cron-tick.nix)
- [modules/services/hermes-agent/runtime/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix)
- [modules/services/hermes-agent/secrets/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/secrets/default.nix)

The Hermes Agent is implemented as a NixOS service that wraps the upstream `hermes-agent` project. This page covers the build pipeline, the runtime environment, and the secret management strategy used to provide the agent with the necessary credentials and system access.

## Build Process and Packaging

The Hermes package is constructed using a multi-stage process that combines `uv2nix` for Python dependency management and `npm-lockfile-fix` for Node.js/Electron components [modules/services/hermes-agent/package/default.nix39-49](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix#L39-L49)

### Source Patching

Before building, the source code is patched to adapt it for the CodyOS environment. Key modifications include:

- **Group Access**: Patches are applied to ensure that files created by Hermes (such as auth stores and home directories) have group read/write permissions (`0o2770` or `stat.S_IRGRP | stat.S_IWGRP`), allowing other system services or users in the group to interact with agent-generated data [modules/services/hermes-agent/package/patches/hermes-home-group-access.patch9-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/patches/hermes-home-group-access.patch#L9-L10)[modules/services/hermes-agent/package/patches/auth-store-group-access.patch10-31](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/patches/auth-store-group-access.patch#L10-L31)
- **Linux Titlebar**: A `postPatch` hook modifies the Electron main process to enable custom titlebar overlays on Linux, which are otherwise restricted to WSL or Windows in the upstream source [modules/services/hermes-agent/package/default.nix18-31](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix#L18-L31)

### Binary Wrappers

The package generates two primary entry points via a `symlinkJoin` and a custom `postBuild` script:

1. **`hermes-desktop`**: A wrapper for the Electron GUI that explicitly sets `HERMES_HOME` to the service's state directory [modules/services/hermes-agent/package/default.nix77-83](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix#L77-L83)
2. **`hermes`**: A unified CLI wrapper. If called with `desktop` or `gui` arguments, it execs the desktop wrapper; otherwise, it passes through to the standard Hermes CLI [modules/services/hermes-agent/package/default.nix85-95](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix#L85-L95)

### Package Architecture

The following diagram illustrates the relationship between the Nix build entities and the resulting binaries.

**Hermes Build and Wrapper Flow**

```

```

Sources: [modules/services/hermes-agent/package/default.nix11-96](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/package/default.nix#L11-L96)

## Runtime Configuration

The Hermes runtime is managed by Systemd, with specific environment variables and security settings to facilitate interaction with other CodyOS components.

### Environment and Variables

- **`CRM_DB`**: Points to the SQLite database used by the CRM system at `/home/codyt/.crm/crm.db`[modules/services/hermes-agent/runtime/default.nix9-31](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L9-L31)
- **`LD_LIBRARY_PATH`**: Includes paths for OpenGL drivers and `libopus` to support voice and media processing [modules/services/hermes-agent/runtime/default.nix10-33](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L10-L33)
- **`HERMES_HOME`**: Set to `${stateDir}/.hermes` to ensure all persistent agent state (identity, keys, logs) is stored in the managed service directory [modules/services/hermes-agent/runtime/cron-tick.nix20](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/cron-tick.nix#L20-L20)

### Systemd Service Tuning

The `hermes-agent` service includes specific configuration for stability and access:

- **`UMask = "0007"`**: Ensures that files created by the service are accessible by the group (typically `hermes-agent` or `users`) [modules/services/hermes-agent/runtime/default.nix37](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L37-L37)
- **`TimeoutStopSec = 210`**: Provides a long grace period for the agent to gracefully shut down and save state [modules/services/hermes-agent/runtime/default.nix36](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L36-L36)
- **`restartTriggers`**: The service is automatically restarted if the `services.hermes-agent.settings` (converted to JSON) change [modules/services/hermes-agent/runtime/default.nix24-28](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L24-L28)

### Cron Integration

A secondary service, `hermes-agent-cron-tick`, runs on a schedule (07:00 and 23:00) to process scheduled tasks. It uses `ExecStart = "${lib.getExe hermesAgent.package} cron tick"` and is configured to wake the system if necessary [modules/services/hermes-agent/runtime/cron-tick.nix38-53](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/cron-tick.nix#L38-L53)

Sources: [modules/services/hermes-agent/runtime/default.nix23-41](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/default.nix#L23-L41)[modules/services/hermes-agent/runtime/cron-tick.nix13-55](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/runtime/cron-tick.nix#L13-L55)

## Secrets Management

Secrets are managed using **SOPS-nix**. The configuration separates raw secrets from the environment file used by the agent.

### Secret Definitions

The following secrets are declared and assigned to the Hermes service user/group:

- **API Keys**: `opencode-api-key`, `firecrawl-api-key`, and `karakeep-api-key`[modules/services/hermes-agent/secrets/default.nix6-7](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/secrets/default.nix#L6-L7)[modules/services/hermes-agent/mcp/default.nix22-28](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/mcp/default.nix#L22-L28)
- **Messaging**: Discord and Telegram bot tokens and allowed user lists [modules/services/hermes-agent/secrets/default.nix8-11](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/secrets/default.nix#L8-L11)

### Secret Injection Patterns

Secrets are injected into the agent in two ways:

1. **Environment Template**: A SOPS template named `hermes-env` aggregates multiple keys into a single file format compatible with the agent's environment loader [modules/services/hermes-agent/secrets/default.nix14-23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/secrets/default.nix#L14-L23)
2. **MCP Wrapper**: For the Model Context Protocol (MCP), a shell application `karakeep-mcp` is created. It reads the API key from the SOPS secret path at runtime and exports it before executing the Node.js MCP server [modules/services/hermes-agent/mcp/default.nix8-18](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/mcp/default.nix#L8-L18)

**Secret Data Flow**

```

```

Sources: [modules/services/hermes-agent/secrets/default.nix4-24](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/secrets/default.nix#L4-L24)[modules/services/hermes-agent/mcp/default.nix8-32](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/mcp/default.nix#L8-L32)

## Summary of Configuration Files

| File | Purpose |
| --- | --- |
| `package/default.nix` | Defines the build logic, patches, and binary wrappers. |
| `runtime/default.nix` | Configures Systemd service, environment variables, and restart triggers. |
| `runtime/cron-tick.nix` | Implements the scheduled task runner and timer. |
| `secrets/default.nix` | Defines SOPS secrets and the environment variable template. |
| `mcp/default.nix` | Bridges external services to Hermes via secret-wrapped MCP servers. |

Sources: [modules/services/hermes-agent/AGENTS.md23-36](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/AGENTS.md?plain=1#L23-L36)