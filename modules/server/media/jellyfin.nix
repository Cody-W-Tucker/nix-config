{
  config,
  mkMediaVhost,
  ...
}:

{
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "nvidia";

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  services.jellyfin = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts = mkMediaVhost {
    host = "media.homehub.tv";
    port = 8096;
  };
}
