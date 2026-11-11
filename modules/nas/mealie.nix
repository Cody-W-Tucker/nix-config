{
  config,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  inherit (config.codyos.site) domain;
  cfg = config.services.mealie;
in
{
  # WORKAROUND (2026-11-10): stable 26.05 ships Mealie 3.16.0, but the NAS
  # database was already migrated by 3.22.0 (former nixpkgs-prior pin), and
  # Mealie migrations cannot run backwards. Track unstable until stable catches up.
  # Upstream: https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/me/mealie
  # REVIEW-BY: 2026-12-31 — drop `package` once the warning below fires.
  services.mealie = {
    enable = true;
    package = pkgs.unstable.mealie;
    port = 9000;
  };

  warnings =
    lib.optional (cfg.enable && lib.versionAtLeast pkgs.mealie.version cfg.package.version)
      "Stable mealie (${pkgs.mealie.version}) has caught up with the unstable pin (${cfg.package.version}); remove `services.mealie.package` from modules/nas/mealie.nix.";

  services.nginx.virtualHosts = mkNginxVhost {
    host = "mealie.${domain}";
    port = 9000;
  };

  nas.backups.sqlite = [
    {
      name = "mealie";
      source = "/var/lib/mealie/mealie.db";
    }
  ];
}
