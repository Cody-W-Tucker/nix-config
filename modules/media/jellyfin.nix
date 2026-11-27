{
  den.aspects.jellyfin.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Jellyfin = {
        group = "Consume";
        order = 10;
        card = {
          icon = "jellyfin";
          href = "https://media.${domain}";
          description = "Media Server";
        };
      };

      systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "nvidia";

      users.users.jellyfin.extraGroups = [
        "render"
        "video"
      ];

      services.jellyfin = {
        enable = true;
        group = "media";
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "media.${domain}";
        port = 8096;
        proxyWebsockets = true;
      };

      nas.backups.sqlite = [
        {
          name = "jellyfin";
          source = "/var/lib/jellyfin/data/jellyfin.db";
        }
      ];
    };
}
