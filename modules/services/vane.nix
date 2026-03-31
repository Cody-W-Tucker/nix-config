# Vane AI Search Tool
# https://github.com/ItzCrazyKns/Vane
#
# This uses the official Docker image with optional patches mounted at runtime
# instead of building from source (which requires complex Node.js native addon handling)

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Directory for runtime patches (applied via volume mount)
  vanePatchesDir = "/var/lib/vane-patches";

in
{
  # Enable Docker
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Vane Container - Single-container AI search tool
  virtualisation.oci-containers.containers."vane" = {
    image = "itzcrazykns1337/vane:latest";
    ports = [
      "3000:3000/tcp"
    ];
    volumes = [
      "vane-data:/home/vane/data:rw"
      # Mount patches directory if you have custom modifications
      # "${vanePatchesDir}:/app/patches:ro"
    ];
    log-driver = "journald";
    autoStart = true;
    extraOptions = [
      "--network=vane"
    ];
    # Optional: Add environment variables for configuration
    environment = {
      PORT = "3000";
      # Add other Vane config here
    };
  };

  # Docker network for Vane
  systemd.services."docker-network-vane" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f vane";
    };
    script = ''
      docker network inspect vane || docker network create vane
    '';
    wantedBy = [ "multi-user.target" ];
  };

  # Docker volume for persistent data
  systemd.services."docker-volume-vane-data" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect vane-data || docker volume create vane-data
    '';
    wantedBy = [ "multi-user.target" ];
  };

  # Ensure container waits for network and volume
  systemd.services."docker-vane" = {
    after = [
      "docker-network-vane.service"
      "docker-volume-vane-data.service"
    ];
    requires = [
      "docker-network-vane.service"
      "docker-volume-vane-data.service"
    ];
    wantedBy = [ "multi-user.target" ];
  };

  # Create patches directory (for runtime customization)
  systemd.tmpfiles.rules = [
    "d ${vanePatchesDir} 0755 root root -"
  ];

  # Firewall - allow access to Vane web UI
  networking.firewall.allowedTCPPorts = [ 3000 ];
}
