{
  # Jellyfin runs as a systemd service, not a login shell, so environment.sessionVariables
  # from the nvidia module don't apply. Tell ffmpeg to use the nvidia VA-API backend.
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "nvidia";

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  services.jellyfin = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."media.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
