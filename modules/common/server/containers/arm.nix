{ config, pkgs, ... }:
{
  virtualisation.oci-containers.containers."automatic-ripping-machine" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "/home/codyt/containers/arm:latest";
    ports = [ "8080:8080" ];
    environment = {
      ARM_UID = "1002"; # You might need to replace this with the actual UID if the substitution doesn't work here
      ARM_GID = "994"; # Same as above for GID
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "docker" ];
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
  };

  users.groups.arm = { };

}

#docker run -d -p "8080:8080" -e ARM_UID="1002" -e ARM_GID="994" -v "/home/codyt:/home/arm" -v "/mnt/media/Music:/home/arm/Music" -v "/home/codyt/logs:/home/arm/logs" -v "/mnt/media:/home/arm/media" -v "/etc/arm/config:/etc/arm/config" --device="/dev/sr0:/dev/sr0" --privileged --restart "always" --name "automatic-ripping-machine" automatic-ripping-machine
