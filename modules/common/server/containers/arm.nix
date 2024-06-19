{ config, pkgs, ... }:
{
  virtualisation.oci-containers.containers."automatic-ripping-machine" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "/home/codyt/containers/arm:latest";
    ports = [ "8080:8080" ];
    environment = {
      ARM_UID = "$(id -u arm)"; # You might need to replace this with the actual UID if the substitution doesn't work here
      ARM_GID = "$(id -g arm)"; # Same as above for GID
    };
    volumes = [
      "/home/arm:/home/arm"
      "/home/arm/Music:/home/arm/Music"
      "/home/arm/logs:/home/arm/logs"
      "/home/arm/media:/home/arm/media"
      "/etc/arm/config:/etc/arm/config"
    ];
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--device=/dev/sr1:/dev/sr1"
      "--device=/dev/sr2:/dev/sr2"
      "--device=/dev/sr3:/dev/sr3"
      "--privileged"
    ];
  };
  # Opening port for ARM
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8080 ];
  };
}
