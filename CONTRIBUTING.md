# Contributing

This repository contains the NixOS configuration for CodyOS: a small multi-machine homelab and workstation setup.

The goals of this repo are:

- keep machines reproducible
- keep configuration easy to find and reason about
- make changes safe to review and test
- avoid hidden one-off behavior

## Repository layout

```text
.
|- flake.nix           # flake inputs and host wiring
|- hosts/              # machine-specific config
|- modules/            # reusable NixOS modules
|- cody/               # Home Manager config for the primary user
|- secrets/            # SOPS declarations and encrypted secrets
|- .agents/            # internal agent/reference docs
`- README.md           # notes for bringing up a new machine
```

## Hosts in this repo

- `beast` - desktop workstation
- `aiserver` - AI workstation
- `server` - media and homelab server

## Core principles

### Keep host files thin

Files in `hosts/` should mostly contain:

- machine imports
- boot and kernel settings
- disks, mounts, and swap
- hostname and machine networking
- hardware-specific overrides
- small host-only package additions
- `system.stateVersion`

Do not put large reusable service definitions directly in a host file unless they are truly one-off to that machine.

### Keep modules single-purpose

Files in `modules/` should each own one feature, service, or tightly related concern.

Good examples:

- one service module such as `paperless.nix`
- one hardware module such as `nvidia.nix`
- one desktop feature such as `printing.nix`

Bad examples:

- `misc.nix`
- `extra.nix`
- large modules that configure many unrelated features

### Separate system config from user config

- `modules/` and `hosts/` are for NixOS system configuration
- `cody/` is for Home Manager user configuration

System services, filesystems, firewall rules, and hardware belong in NixOS.

Shell config, editor config, CLI tools, and user applications usually belong in Home Manager.

### Keep custom packages separate from modules

The current repo uses `modules/scripts/` for custom script packages. Conceptually, files that build derivations or wrappers are package definitions, not NixOS modules.

When adding new code, keep this distinction in mind even if the directory is not renamed yet.

## Naming standards

Use lowercase kebab-case almost everywhere.

Examples:

- `homepage-dashboard.nix`
- `hardware-configuration.nix`
- `rofi-web-launcher.nix`

Avoid:

- `paperlessNgx.nix`
- `paperless_ngx.nix`
- `Stuff.nix`

Additional naming rules:

- host files should match the hostname when practical
- module names should match the feature or service they configure
- importable directories should use `default.nix`
- secret keys should be descriptive, for example `sops.secrets."paperless-password"`

## What belongs in each kind of file

### `flake.nix`

Keep `flake.nix` focused on wiring:

- flake inputs
- shared package imports
- `nixosConfigurations`
- formatter and checks

Avoid putting detailed service logic in `flake.nix`.

### `hosts/*.nix`

Expected contents:

- imports of reusable modules
- bootloader and initrd settings
- filesystems and swap
- hostname
- hardware-specific settings
- machine-local overrides
- host `system.stateVersion`

### `modules/**/*.nix`

Expected contents:

- reusable NixOS config
- service definitions
- firewall rules related to that feature
- nginx virtual hosts related to that feature
- secrets declarations close to where they are used

If a service exposes a port, prefer a local `let` binding when it makes the module easier to read.

### `cody/**/*.nix`

Expected contents:

- `home.packages`
- `programs.*` configuration
- shell aliases and session variables
- user desktop configuration
- user theming and editor setup
- `home.stateVersion`

### `default.nix`

Prefer using `default.nix` as a simple import aggregator.

Example:

```nix
{ ... }:

{
  imports = [
    ./printing.nix
    ./logging.nix
    ./hyprland.nix
  ];
}
```

Do not hide lots of unrelated configuration in aggregator files.

## Patterns used in this repo

### Nginx reverse proxies

Common pattern:

```nix
services.nginx.virtualHosts."service.homehub.tv" = {
  useACMEHost = "homehub.tv";
  forceSSL = true;
  locations."/".proxyPass = "http://localhost:8080";
};
```

If the proxy exists only for one service, keep the nginx config in the same module as that service.

### Docker and OCI containers

Common pattern:

```nix
virtualisation.oci-containers.containers.name = {
  image = "image:tag";
  ports = [ "8080:8080" ];
};
```

Put container config in a service-focused module, not directly in a host unless it is truly machine-specific.

### Secrets

Use SOPS declarations like:

```nix
sops.secrets."key-name" = { };
```

Rules:

- never commit raw secrets
- keep secret declarations close to the service that consumes them
- reference secret paths through `config.sops.secrets.<name>.path`

## NixOS-specific pitfalls to avoid

### NixOS modules are merged, not executed linearly

Do not think of modules like shell scripts or imperative programs.

- import order is not normal execution order
- values are merged across modules
- the module system behaves differently from plain Nix expressions

### Do not over-abstract too early

Do not create custom options or helper layers unless they clearly improve reuse.

Create custom options when:

- multiple hosts share the feature
- the feature should be enabled or disabled cleanly
- you need stable defaults with host overrides

If only one host uses it and the logic is simple, direct configuration is usually better.

### Keep `stateVersion` local

- `system.stateVersion` belongs in the host file
- `home.stateVersion` belongs in the Home Manager user config

Do not centralize these in a shared module.

### Remember that flakes only see tracked files

New files often need to be added to git before flake evaluation can see them.

If you add a file and Nix says it does not exist, first confirm it is tracked.

## Editing standards

- use ASCII unless a file already needs Unicode
- prefer small, focused modules over giant shared files
- add comments only when the code is not obvious
- keep section ordering readable and consistent
- prefer descriptive names over clever abstractions

Suggested section order inside a module:

1. function arguments
2. `let` bindings
3. `imports`
4. secrets declarations
5. main config

## Validation workflow

Before merging or switching, run the narrowest useful validation.

### Build a specific host

```bash
sudo nixos-rebuild build --flake .#beast
sudo nixos-rebuild build --flake .#aiserver
sudo nixos-rebuild build --flake .#server
```

### Switch the current host

```bash
sudo nixos-rebuild switch --flake .
```

### General checks

```bash
nix flake check
```

When changing a service or host module, prefer a host build over relying only on formatting or evaluation.

## Typical workflows

### Add a new service

1. Create a new module in the appropriate category under `modules/`
2. Add secrets next to the service if needed
3. Add nginx or firewall config in the same module when it is specific to that service
4. Import the module through the relevant `default.nix` or host
5. Enable or wire it in the target host
6. Build the target host

### Add a new host

1. Create a new file under `hosts/` named for the hostname
2. Import shared modules and hardware modules
3. Add filesystems, boot config, hostname, and host overrides
4. Set a host-local `system.stateVersion`
5. Register the host in `flake.nix`
6. Build that host with `nixos-rebuild build --flake .#<host>`
7. Update SOPS keys if the machine needs secrets

## Review checklist

Before opening a PR or committing a change, ask:

- Is the file in the right place?
- Is the name clear and consistent?
- Is the host file still mostly machine-specific?
- Is the module single-purpose?
- Are secrets declared safely?
- Did I keep `stateVersion` local to the host or user?
- Did I build the affected host?

## Final guidance

The best changes in this repo are boring to navigate:

- a new contributor can guess where a change belongs
- a reviewer can tell what a file owns
- a future refactor does not need detective work

When in doubt, choose the structure that reduces surprise.
