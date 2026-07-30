{
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

  # Jellyfin's NixOS module doesn't expose a port option (port is configured
  # in the Jellyfin Web UI); 8096 is the upstream default HTTP port.
  services.nginx.virtualHosts = mkMediaVhost {
    host = "media.homehub.tv";
    port = 8096;
  };
}
