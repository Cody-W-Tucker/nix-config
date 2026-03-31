# Vane AI Search Tool
# Simple single-container AI search interface
# https://github.com/itzcrazykns1337/Vane

{
  config,
  lib,
  pkgs,
  ...
}:

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
    ];
    log-driver = "journald";
    autoStart = true;
    extraOptions = [
      "--network=vane"
    ];
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

  # Firewall - allow access to Vane web UI
  networking.firewall.allowedTCPPorts = [ 3000 ];
}
