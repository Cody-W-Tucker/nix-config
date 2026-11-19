{
  den.aspects.navidrome.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Navidrome = {
        group = "Consume";
        order = 20;
        card = {
          href = "https://music.${domain}";
          icon = "navidrome";
          description = "Music Server";
        };
      };

      services.navidrome = {
        enable = true;
        group = "media";
        settings = {
          MusicFolder = "/mnt/media/Music";
        };
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "music.${domain}";
        port = config.services.navidrome.settings.Port;
      };

      nas.backups.sqlite = [
        {
          name = "navidrome";
          source = "/var/lib/navidrome/navidrome.db";
        }
      ];
    };
}
