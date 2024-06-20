{ config, pkgs, ... }:
{
  virtualisation.oci-containers.containers."automatic-ripping-machine" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "automatic-ripping-machine:latest";
    login.registry = "docker.io";
    ports = [ "8080:8080" ];
    environment = {
      ARM_UID = "1002";
      ARM_GID = "994";
    };
    volumes = [
      "/home/arm/:/home/arm"
      "/mnt/media/Music:/home/arm/Music"
      "/home/arm/logs:/home/arm/logs"
      "/mnt/media:/home/arm/media"
      "/home/arm/config:/etc/arm/config"
    ];
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--privileged"
    ];
  };
  # Opening port for ARM
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8080 ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "docker" ];
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
  };

  users.groups.arm = { };

  # Enable udev for docker
  services.udev.enable = true;

}

#docker run -d -p "8080:8080" -e ARM_UID="1002" -e ARM_GID="994" -v "/home/arm:/home/arm" -v "/mnt/media/Music:/home/arm/Music" -v "/home/arm/logs:/home/arm/logs" -v "/mnt/media:/home/arm/media" -v "/etc/arm/config:/etc/arm/config" --device="/dev/sr0:/dev/sr0" --privileged --name "automatic-ripping-machine" automaticrippingmachine/automatic-ripping-machine:latest

