{
  config,
  mkNginxVhost,
  ...
}:

{
  services.navidrome = {
    enable = true;
    group = "media";
    settings = {
      MusicFolder = "/mnt/media/Music";
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "music.homehub.tv";
    port = config.services.navidrome.settings.Port;
  };

  nas.backups.sqlite = [
    { name = "navidrome"; source = "/var/lib/navidrome/navidrome.db"; }
  ];
}
