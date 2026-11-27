{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.photos ];

  den.aspects.photos.nixos =
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
      codyos.homepage.cards.Photos = {
        group = "Collect";
        order = 20;
        card = {
          href = "https://photos.${domain}";
          icon = "immich";
          description = "Photo Management";
        };
      };

      services.immich = {
        enable = true;
        package = pkgs.unstable.immich;
        host = "127.0.0.1";
        mediaLocation = "/mnt/backup/photos";
        group = "media";

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
    };
}
