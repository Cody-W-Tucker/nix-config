{
  services.immich = {
    enable = true;
    port = 2283;
    mediaLocation = "/mnt/hdd/Photos";
  };

  users.users.immich.extraGroups = [ "video" "render" "media" ];

  # NGINX
  services.nginx.virtualHosts."photos.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
  };

  # Syncthing backup
  services.syncthing.settings.folders."photos" = {
    path = "/mnt/hdd/Photos";
    devices = [ "server" "workstation" ];
    ignorePerms = true;
  };
}
