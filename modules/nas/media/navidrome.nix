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
}
