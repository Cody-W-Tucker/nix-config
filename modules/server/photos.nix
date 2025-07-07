{
  services.immich = {
    enable = false;
    port = 2283;
    host = "localhost";
    mediaLocation = "/mnt/media/Photos";
    group = "media";
  };

  # users.users.immich.extraGroups = [ "video" "render" "media" ];

  # NGINX
  services.nginx.virtualHosts."photos.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:2283";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
    kTLS = true;
  };

  # Backup photos to workstation hard drive
  services.borgbackup.jobs.photos = {
    user = "codyt";
    group = "media";
    paths = "/mnt/media/Photos/originals";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i /home/codyt/.ssh/id_ed25519";
    repo = "codyt@192.168.1.238:/mnt/backup/Photos";
    compression = "lz4";
    startAt = "daily";
  };
}
