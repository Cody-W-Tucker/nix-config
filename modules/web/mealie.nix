{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.mealie ];

  den.aspects.mealie.nixos =
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
      services.mealie = {
        enable = true;
        package = pkgs.unstable.mealie;
      };

      codyos.workarounds.mealie-unstable = {
        reason = "Stable ships Mealie ${pkgs.mealie.version}, but the NAS database was migrated by 3.22.0 and Mealie migrations cannot run backwards, so services.mealie.package tracks unstable.";
        upstream = "https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/me/mealie";
        reviewBy = "2027-02-27";
        obsolete = lib.versionAtLeast pkgs.mealie.version "3.22.0";
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "mealie.${domain}";
        inherit (cfg) port;
      };

      nas.backups.sqlite = [
        {
          name = "mealie";
          source = "/var/lib/mealie/mealie.db";
        }
      ];
    };
}
