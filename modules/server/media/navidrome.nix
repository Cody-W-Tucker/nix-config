{ mkMediaVhost, ... }:

{
  services.navidrome = {
    enable = true;
    group = "media";
    settings = {
      MusicFolder = "/mnt/media/Music";
    };
  };

  services.nginx.virtualHosts = mkMediaVhost {
    host = "music.homehub.tv";
    port = 4533;
  };
}
