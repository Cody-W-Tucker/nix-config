{ config, lib, ... }:
{
  # Shared baseline for every host: system modules, shared feature options, boot/firmware.
  # Per-host site facts (lan, tailscale, mac) come from the den host attributes in
  # modules/hosts/<host>.nix; every host receives them as `codyos.site.hosts`.
  # (The codyos.site option itself is declared in modules/_legacy/system/site.nix.)
  # Kept in this single module: a second contribution to den.aspects.base.nixos
  # would reorder module merging (e.g. systemd.tmpfiles.rules) and change drvs.
  den.aspects.base.nixos = {
    imports = [
      ../_legacy/system/base.nix
      ../_legacy/hardware/baseline.nix
    ];
    codyos.site.hosts = lib.mkOptionDefault (
      lib.mapAttrs (
        _: host:
        {
          inherit (host) lan tailscale;
        }
        // lib.optionalAttrs (host ? mac) { inherit (host) mac; }
      ) config.den.hosts.x86_64-linux
    );
  };
}
