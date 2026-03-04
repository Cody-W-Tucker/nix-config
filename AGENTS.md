# CodyOS

NixOS config for home lab with 3 machines.

## Hosts
- **beast** - Desktop (i9-14900KF, RTX 3070)
- **aiserver** - AI workstation (Strix Halo AI 395+)
- **server** - Media/server (i7-7000)

## Build
```bash
# Build and switch
sudo nixos-rebuild switch --flake .

# Build specific host
sudo nixos-rebuild build --flake .#beast
```

## Structure
```
hosts/        - machine configs
modules/      - reusable (desktop/, server/, scripts/)
cody/         - user configs (cli/, ui/)
secrets/      - SOPS-encrypted
```

## Patterns
```nix
# Nginx reverse proxy (common in this repo)
services.nginx.virtualHosts."service.homehub.tv" = {
  forceSSL = true;
  useACMEHost = "homehub.tv";
  locations."/".proxyPass = "http://localhost:8080";
};

# Docker container
virtualisation.oci-containers.containers.name = {
  image = "image:tag";
  ports = [ "8080:8080" ];
};
```

## Secrets
- Use SOPS: `sops.secrets."key" = { };`
- Never commit raw secrets
