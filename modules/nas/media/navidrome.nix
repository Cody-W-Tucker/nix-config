{
  config,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
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
}
