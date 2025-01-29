{ config, pkgs, ... }:
let userDir = "${config.users.users.codyt.home}";
in
{
  services.jellyfin = {
    enable = true;
    openFirewall = false;
    user = "codyt";
  };
  # IPTV client
  virtualisation.oci-containers.containers."threadfin" = {
    autoStart = true;
    image = "fyb3roptik/threadfin:latest";
    extraOptions = [ "--pull=always" ];
    ports = [ "127.0.0.1:34400:34400" ];
    environment = {
      PUID = "1001";
      PGID = "1001";
      TZ = "America/Chicago";
    };
    volumes = [
      "${userDir}/threadfin:/home/threadfin/conf"
      "${userDir}/threadfin:/tmp/threadfin:rw"
    ];
  };
  # NGINX
  services.nginx = {
    virtualHosts = {
      "media.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
      };
      "threadfin.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://127.0.0.1:34400";
          proxyWebsockets = true;
        };
      };
    };
  };

  # Syncthing backup
  services.syncthing.settings.folders."media" = {
    path = "/mnt/hdd/Media";
    devices = [ "server" "workstation" ];
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];

  # 1. enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver # previously vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      intel-media-sdk # QSV up to 11th gen
    ];
  };
}
