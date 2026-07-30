{
  services.navidrome = {
    enable = true;
    group = "media";
    settings = {
      MusicFolder = "/mnt/media/Music";
    };
  };

  services.nginx.virtualHosts."music.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://127.0.0.1:4533";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
