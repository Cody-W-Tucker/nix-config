# CodyOS

NixOS flake for 3 machines:

- `beast` - desktop workstation
- `aiserver` - AI workstation
- `server` - media and homelab server

## Build

```bash
# Build current host and switch
sudo nixos-rebuild switch --flake .

# Build a specific host without switching
sudo nixos-rebuild build --flake .#beast

# General repo checks
nix flake check
```

## Repo map

```text
hosts/      machine-specific config
modules/    reusable NixOS modules
cody/       Home Manager config
secrets/    SOPS declarations and encrypted material
```

## High-value repo rules

- Keep `hosts/` thin: boot, disks, hostname, hardware, host overrides, `system.stateVersion`
- Keep `modules/` single-purpose: one service, feature, or hardware concern per file
- Put user programs and shell config in `cody/`, not in system modules
- Treat `modules/scripts/` as package-like code even though it currently lives under `modules/`
- Keep `default.nix` mostly as an import aggregator
- Use lowercase kebab-case file names
- Keep `system.stateVersion` host-local and `home.stateVersion` user-local
- New files must be git-tracked or flakes may not see them
- Never commit raw secrets

## Common patterns

```nix
# SOPS secret
sops.secrets."service-key" = { };

# Nginx reverse proxy
services.nginx.virtualHosts."service.homehub.tv" = {
  useACMEHost = "homehub.tv";
  forceSSL = true;
  locations."/".proxyPass = "http://localhost:8080";
};

# OCI container
virtualisation.oci-containers.containers.name = {
  image = "image:tag";
  ports = [ "8080:8080" ];
};
```

## What to optimize for

- Reusable logic in `modules/`
- Machine identity in `hosts/`
- User environment in `cody/`
- Low surprise over clever abstraction
