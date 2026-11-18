{
  config,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
  services.immich = {
    enable = true;
    # Pull Immich from nixpkgs-unstable while the NAS host stays on stable.
    package = pkgs.unstable.immich;
    host = "127.0.0.1";
    mediaLocation = "/mnt/backup/photos";
    group = "media";

    # Expose GPU 0 to Immich ML via narrow NVIDIA device allowlist.
    # Setting a non-empty accelerationDevices makes PrivateDevices=false
    # (default [] means PrivateDevices=true, blocking all GPU access).
    machine-learning.environment = {
      CUDA_VISIBLE_DEVICES = "0";
    };
    accelerationDevices = [
      "/dev/nvidiactl"
      "/dev/nvidia0"
      "/dev/nvidia-uvm"
    ];
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
    "media"
  ];

  # NGINX
  services.nginx.virtualHosts = mkNginxVhost {
    host = "photos.${domain}";
    inherit (config.services.immich) port;
    proxyWebsockets = true;
    locationExtraConfig = ''
      client_max_body_size 50000M;
      proxy_read_timeout   600s;
      proxy_send_timeout   600s;
      send_timeout         600s;
    '';
  };
}
