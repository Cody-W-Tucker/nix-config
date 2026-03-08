# NixOS Module Design

Use this guide when deciding what should go inside host files, service modules, Home Manager modules, and related configuration files.

## Mental model

Treat each module as a unit of responsibility.

- Hosts describe a machine.
- Modules describe reusable features.
- Home Manager files describe user environments.
- Package files build packages.

## Main file categories

### Host files

Expected contents:

- imports for shared modules
- bootloader settings
- kernel and initrd settings
- filesystems and swap
- hostname and machine networking
- hardware-specific overrides
- host-only package additions
- host `system.stateVersion`

Keep host files thin and machine-specific.

Example:

```nix
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ../modules/system
    ../modules/desktop
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  networking.hostName = "beast";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/...";
    fsType = "ext4";
  };

  environment.systemPackages = with pkgs; [ prismlauncher ];

  system.stateVersion = "25.05";
}
```

### Service modules

Expected contents:

- a single service or tightly related feature
- required secrets close to usage
- ports as local variables when useful
- service config, proxy config, firewall openings, and backup hooks related to that service

Prefer one service per file.

Example:

```nix
{ config, lib, ... }:

let
  port = 28981;
in
{
  sops.secrets."paperless-password" = { };

  services.paperless = {
    enable = true;
    inherit port;
    passwordFile = config.sops.secrets."paperless-password".path;
  };

  services.nginx.virtualHosts."paperless.example.com" = {
    useACMEHost = "example.com";
    forceSSL = true;
    locations."/".proxyPass = "http://localhost:${toString port}";
  };
}
```

### System modules

Expected contents:

- shared Nix settings
- locale and time
- common users and groups
- logging defaults
- shared firewall defaults
- package sets common to many machines

These modules should be broadly reusable and avoid host-specific assumptions.

### Hardware modules

Expected contents:

- device drivers
- kernel modules
- vendor-specific services
- GPU or CPU tuning
- firmware and hardware workarounds

Keep vendor or device details out of generic system modules.

### Home Manager modules

Expected contents:

- `home.packages`
- `programs.*` configuration
- shell aliases and CLI defaults
- desktop user apps and dotfiles
- theme and user session settings
- user `home.stateVersion`

Keep system-level concerns out of Home Manager files unless the option is explicitly exposed there.

### Package files

Expected contents:

- `stdenv.mkDerivation`, `writeShellApplication`, `callPackage`, or similar package definitions
- wrappers, scripts, or custom derivations

Do not use package files as a dumping ground for system configuration.

## Common module categories

Useful categories include:

- `system/`
- `services/`
- `networking/`
- `security/`
- `desktop/`
- `hardware/`
- `virtualization/`
- `users/` or `home/`

These are conventions, not hard requirements. The key standard is consistency.

## `default.nix` expectations

Use `default.nix` mostly as an import aggregator:

```nix
{ ... }:

{
  imports = [
    ./nginx.nix
    ./paperless.nix
    ./monitoring.nix
  ];
}
```

Avoid hiding real configuration inside aggregator files unless the file genuinely represents a shared feature itself.

## Preferred section order inside a module

1. function arguments
2. `let` bindings
3. `imports`
4. local `options` definitions if creating custom modules
5. secrets declarations
6. main `config` body or direct option assignments

## Rule of thumb

If removing the file would disable exactly one feature or one machine concern, the module boundary is probably good.
