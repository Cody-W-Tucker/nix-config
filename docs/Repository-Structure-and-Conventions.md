# Repository Structure and Conventions
Relevant source files
- [.gitignore](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/.gitignore)
- [AGENTS.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1)
- [CONTRIBUTING.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1)
- [flake.lock](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.lock)
- [flake.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix)
- [hosts/AGENTS.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/hosts/AGENTS.md?plain=1)
- [modules/AGENTS.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/AGENTS.md?plain=1)
- [modules/services/hermes-agent/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/default.nix)
- [modules/services/llama-swap/README.md](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/README.md?plain=1)

This page details the organizational standards, directory layout, and naming conventions of the CodyOS repository. The structure is designed to maintain a clear separation between system-level NixOS configuration, user-level Home Manager settings, and reusable service modules while facilitating AI-assisted maintenance.

## Top-Level Directory Layout

The repository follows a functional decomposition strategy, ensuring that machine-specific facts are isolated from reusable logic.

| Directory | Purpose | Key Contents |
| --- | --- | --- |
| `hosts/` | Machine-specific entry points and hardware facts. | `beast/`, `server.nix` |
| `modules/` | Reusable NixOS system-level modules and services. | `system/`, `services/`, `desktop/`, `server/` |
| `users/` | Home Manager configurations (aliased as `cody/` in some contexts). | Shell, UI, and app configs. |
| `packages/` | Custom derivations and system scripts. | `system-scripts/`, `kokoro/` |
| `.agents/` | Knowledge base and guidance for AI agents. | `skills/`, `AGENTS.md` |
| `wallpapers/` | Wallpaper assets referenced by desktop configuration. | Static image assets |

### System Architecture Data Flow

The following diagram illustrates how `flake.nix` wires these directories into a functional NixOS configuration.

**CodyOS Configuration Data Flow**

```mermaid
flowchart LR
    subgraph subGraph0 ["Code Entity Space"]
        FLAKE["flake.nix"]
        HOSTS["hosts/ (beast/server)"]
        MODS["modules/ (system/services)"]
        USERS["users/ (home-manager)"]
        PKGS["packages/ (custom)"]
        SECRETS["nixos-secrets (Private Flake)"]
    end
    FLAKE --> HOSTS
    HOSTS --> MODS
    HOSTS --> USERS
    MODS --> PKGS
    MODS --> SECRETS
```

**Sources:**[flake.nix115-129](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L115-L129)[CONTRIBUTING.md12-23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L12-L23)[hosts/AGENTS.md1-6](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/hosts/AGENTS.md?plain=1#L1-L6)

---

## Naming and File Conventions

To ensure consistency across the codebase, the following rules are enforced:

### 1. Case and Format

- **kebab-case:** All file and directory names must use lowercase kebab-case (e.g., `hardware-configuration.nix`, `homepage-dashboard.nix`) [CONTRIBUTING.md77-84](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L77-L84)
- **Secret Keys:** Use quoted attribute names for secret keys containing dashes, such as `sops.secrets."paperless-password"`[AGENTS.md28-30](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1#L28-L30)

### 2. The `default.nix` Pattern

Importable directories should use a `default.nix` file as a "simple import aggregator" [CONTRIBUTING.md146-150](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L146-L150)

- Keep `default.nix` short.
- Move implementation details to sibling files like `package.nix`, `service.nix`, or `module.nix`[AGENTS.md34-37](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1#L34-L37)
- **Example Structure:**
```
modules/services/hermes-agent/
├── default.nix   # The "spine" that imports other files
├── documents/    # Workspace documents and SOUL installation
├── mcp/          # MCP server wiring
├── package/      # Derivation logic
├── runtime/      # Systemd and environment setup
├── secrets/      # SOPS wiring
├── skills/       # Managed and mutable skills
└── toolsets/     # Tool exposure and trust boundaries
```

**Sources:**[CONTRIBUTING.md146-165](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L146-L165)[modules/services/hermes-agent/default.nix13-22](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/default.nix#L13-L22)[AGENTS.md34-37](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1#L34-L37)

---

## Flake Inputs and Categories

The `flake.nix` file categorizes inputs to balance system stability with the need for cutting-edge desktop features.

### Input Tiers

- **Stable (`nixpkgs`):** Tracks `nixos-25.11`. Primarily used for the `server` host to ensure uptime and service reliability [flake.nix9-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L9-L10)
- **Unstable (`nixpkgs-unstable`):** Tracks `nixos-unstable`. Used for the `beast` workstation to provide the latest Hyprland, AI tools, and kernel updates [flake.nix30-31](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L30-L31)

### Key AI & Agent Inputs

The repo integrates several specialized flakes for the local AI stack:

- `hermes-agent`: The primary cognitive assistant runtime [flake.nix82-86](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L82-L86)
- `rlm`: Recursive Language Model CLI [flake.nix87-90](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L87-L90)
- `llm-agents`: A collection of AI tool pack derivations [flake.nix62-66](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L62-L66)

**Sources:**[flake.nix1-96](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L1-L96)[flake.nix116-128](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/flake.nix#L116-L128)

---

## Agent Guidance (AGENTS.md)

The repository contains `AGENTS.md` files scattered throughout the tree. These files serve as "in-situ" documentation for LLMs (like Claude or GPT-4) when they are operating within the codebase.

### Global Rules [AGENTS.md24-46](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1#L24-L46)

- **Git Tracking:** New files must be `git add`-ed before Nix flakes can see them.
- **No Raw Secrets:** Never commit unencrypted secrets; use `sops-nix`.
- **Sudo:** Agents are informed they do not have `sudo` access and cannot trigger a full system rebuild independently.

### Directory-Specific Guidance

- **`hosts/AGENTS.md`**: Directs agents to keep host files thin, focusing only on hardware facts and role selection [hosts/AGENTS.md7-14](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/hosts/AGENTS.md?plain=1#L7-L14)
- **`modules/AGENTS.md`**: Instructs agents to keep reusable services here and to declare secrets close to the consuming service [modules/AGENTS.md7-15](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/AGENTS.md?plain=1#L7-L15)

**Sources:**[AGENTS.md1-46](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/AGENTS.md?plain=1#L1-L46)[hosts/AGENTS.md1-14](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/hosts/AGENTS.md?plain=1#L1-L14)[modules/AGENTS.md1-15](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/AGENTS.md?plain=1#L1-L15)

---

## Module Logic and Implementation

Modules are designed to be single-purpose and self-contained. `default.nix` acts as the assembly spine, while runtime wiring, secrets, package overrides, MCP integrations, and related support surfaces live in sibling paths when the module grows.

### Service Implementation Pattern

```mermaid
flowchart TD
    subgraph subGraph0 ["Module: modules/services/hermes-agent"]
        DEF["default.nix"]
        DOC["documents/"]
        MCP["mcp/"]
        SEC["secrets/"]
        RUN["runtime/"]
        PKG["package/"]
        SKL["skills/"]
        TOOL["toolsets/"]
    end
    DEF --> DOC
    DEF --> MCP
    DEF --> SEC
    DEF --> RUN
    DEF --> PKG
    DEF --> SKL
    DEF --> TOOL
```

### Nginx and Secrets Wiring

For services like `hermes-agent`, the configuration is made fully declarative by writing the settings to a JSON file and forcing the activation script to overwrite the upstream `config.yaml`[modules/services/hermes-agent/default.nix56-62](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/default.nix#L56-L62) Secrets are injected via `sops.templates`, allowing dynamic environment variables to be populated at runtime [modules/services/hermes-agent/default.nix55](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/default.nix#L55-L55)

**Sources:**[modules/services/hermes-agent/default.nix1-151](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/hermes-agent/default.nix#L1-L151)[CONTRIBUTING.md168-180](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L168-L180)[CONTRIBUTING.md195-208](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/CONTRIBUTING.md?plain=1#L195-L208)
