{
  den.aspects.audiobookshelf.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Audiobookshelf = {
        group = "Consume";
        order = 40;
        card = {
          href = "https://audiobooks.${domain}";
          icon = "audiobookshelf";
          description = "Audiobook and Podcast Server";
        };
      };

      services.audiobookshelf = {
        enable = true;
        group = "media";
        port = 8091;
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "audiobooks.${domain}";
        port = config.services.audiobookshelf.port;
        proxyWebsockets = true;
        locationExtraConfig = ''
          client_max_body_size 10240M;
        '';
      };

      nas.backups.sqlite = [
        {
          name = "audiobookshelf";
          source = "/var/lib/audiobookshelf/config/absdatabase.sqlite";
        }
      ];
    };
}
