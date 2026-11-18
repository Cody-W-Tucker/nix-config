{
  config,
  den,
  lib,
  ...
}:
{
  # Shared baseline for every host: system modules, shared feature options, boot/firmware.
  # Per-host site facts (lan, tailscale, mac) come from the den host attributes in
  # modules/hosts/<host>.nix; every host receives them as `codyos.site.hosts`.
  # (The codyos.site option itself is declared in modules/base/_site.nix.)
  # nginx provides the mkNginxVhost module argument to every module on every host.
  den.aspects.base.includes = [ den.aspects.nginx ];

  # Kept in this single module: a second contribution to den.aspects.base.nixos
  # would reorder module merging (e.g. systemd.tmpfiles.rules) and change drvs.
  den.aspects.base.nixos = {
    imports = [
      ../base/_legacy-base.nix
      ../hardware/_baseline.nix
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
