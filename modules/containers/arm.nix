{ config, pkgs, ... }:

{
  # Allows container to see diskdrives
  boot.kernelModules = [ "sg" ];

  # Open the port of the webui
  networking.firewall.allowedTCPPorts = [ 9090 ];

  # Set the container for ARM
  virtualisation.oci-containers.containers."arm-rippers" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "automaticrippingmachine/automatic-ripping-machine:latest";
    ports = [ "9090:8080" ];
    # Get the UID and GID of the user on the host system
    environment = {
      ARM_UID = "1002";
      ARM_GID = "983";
    };
    volumes = [
      "/home/arm:/home/arm"
      "/home/arm/Music:/home/arm/Music"
      "/home/arm/logs:/home/arm/logs"
      "/home/arm/media:/home/arm/media"
      "/home/arm/config:/etc/arm/config"
    ];
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--device=/dev/dri:/dev/dri"
      "--privileged"
    ];
  };

  # Create a user for the container
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "render" "docker" ];
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
  };

  users.groups.arm = { };

  # Enable udev
  services.udev.enable = true;

}
