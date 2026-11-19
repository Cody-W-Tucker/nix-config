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
|- flake.nix           # flake inputs + evalModules over modules/ (outputs come from there)
|- modules/            # the Den tree: hosts, aspects, flake outputs (see modules/README.md)
|  |- hosts/           # one file per machine (den host + host aspect), hardware in _*-hardware.nix
|  |- base/ hardware/  # shared baseline aspects
|  |- users/ desktop/ editor/ harness/   # user, desktop, editor and AI-harness aspects
|  |- services/ server/                  # cross-class services; NAS role and its services
|  `- flake/           # overlays, packages, checks, formatter
|- packages/           # custom packages (package.nix each), exposed by the overlay
|- docs/               # operator notes and reference
`- .agents/            # internal agent/reference docs
```

The layout and conventions are described in `docs/Den-Native-Layout.md`.

## Hosts in this repo

- `beast` - desktop workstation (nixpkgs-unstable)
- `nas` - media and homelab server (stable nixpkgs)

## Core principles

### Keep host files thin

`modules/hosts/<host>.nix` should mostly contain:

- the `den.hosts` entry (channel pairing, host facts)
- the aspect includes that select roles and features
- machine facts in the host aspect's `nixos` block: boot and kernel settings, mounts, hostname and machine networking, hardware-specific overrides
- `system.stateVersion` and `home.stateVersion`

Hardware config lives in `modules/hosts/_<host>-hardware.nix`. Do not put large reusable service definitions in a host file unless they are truly one-off to that machine.

### Keep modules single-purpose

Aspect files in `modules/` should each own one feature, service, or tightly related concern.

Good examples:

- one service aspect such as `modules/server/paperless.nix`
- one hardware aspect such as `modules/hardware/nvidia.nix`
- one desktop feature such as `modules/desktop/printing.nix`

Bad examples:

- `misc.nix`
- `extra.nix`
- large modules that configure many unrelated features

### System and user config in one aspect

An aspect file can carry both halves of a feature: `nixos` for system config and `homeManager` for the user's Home Manager config. Put each half in the class where it belongs.

System services, filesystems, firewall rules, and hardware belong in `nixos`.

Shell config, editor config, CLI tools, and user applications usually belong in `homeManager`.

### Keep custom packages separate from modules

Files that build derivations or wrappers are package definitions, not NixOS modules. Put them in `packages/<name>/package.nix`; the shared overlay exposes each one as `pkgs.<name>` (see `packages/README.md`). Modules that install them, such as `modules/base/scripts.nix`, stay under `modules/`.

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

- host files should match the hostname (`modules/hosts/<host>.nix`)
- aspect names and file names should match the feature or service they configure
- no `default.nix` outside `_` paths under `modules/` (enforced by `check-imports`); plain module trees under `_` paths may use a short `default.nix` spine
- secret keys should be descriptive, for example `sops.secrets."paperless-password"`

## What belongs in each kind of file

### `flake.nix`

`flake.nix` holds only the inputs and the `evalModules` call that loads `modules/`. Flake outputs (`overlays`, `packages`, `checks`, `formatter`) are defined in `modules/flake/`, and `nixosConfigurations` come from `modules/hosts/`. Do not put logic in `flake.nix`.

### `modules/hosts/*.nix`

Expected contents:

- the `den.hosts` entry and host aspect (includes, `provides.to-users.homeManager`)
- machine facts: bootloader and initrd settings, filesystems and swap, hostname, hardware-specific settings, machine-local overrides
- host `system.stateVersion` and `home.stateVersion`

### `modules/**/*.nix` (outside `_` paths)

Expected contents: a flake-level Den module defining `den.aspects.<name>` (or `flake.*` outputs in `modules/flake/`):

- reusable NixOS config (`nixos`) and user config (`homeManager`)
- service definitions, with firewall rules and nginx virtual hosts related to that feature
- secrets declarations close to where they are used

If a service exposes a port, prefer a local `let` binding when it makes the module easier to read.

### `_`-prefixed files and directories

Plain NixOS/Home Manager modules, package definitions, scripts and data. import-tree ignores them; the owning aspect imports them. A `default.nix` is only allowed here and should stay a simple import aggregator.

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

- `system.stateVersion` belongs in the host aspect (`modules/hosts/<host>.nix`)
- `home.stateVersion` belongs in the host's `provides.to-users.homeManager`

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
sudo nixos-rebuild build --flake .#nas
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

1. Create `modules/<area>/<service>.nix` defining `den.aspects.<service>` (for NAS services, `modules/server/<service>.nix`)
2. Add secrets next to the service if needed
3. Add nginx or firewall config in the same file when it is specific to that service
4. Include the aspect from a role or host aspect (`modules/server/server.nix`, `modules/hosts/<host>.nix`)
5. `git add` the file and build the target host

### Add a new host

1. Follow `modules/README.md` (Adding a host): `modules/hosts/<host>.nix` plus `_<host>-hardware.nix`
2. Set host-local `system.stateVersion` and the host's `home.stateVersion`
3. Build that host with `nixos-rebuild build --flake .#<host>`
4. Update SOPS keys if the machine needs secrets

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
