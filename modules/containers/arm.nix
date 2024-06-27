{ config, pkgs, ... }:
# docker run -d \
#    -p "8080:8080" \
#    -e ARM_UID="1002" \
#    -e ARM_GID="983" \
#    -v "/home/arm:/home/arm" \
#    -v "/home/arm/Music:/home/arm/Music" \
#    -v "/home/arm/logs:/home/arm/logs" \
#    -v "/home/arm/media:/home/arm/media" \
#    -v "/home/arm/config:/etc/arm/config" \
#    --device=/dev/sr0:/dev/sr0 \
#    --privileged \
#    --restart "always" \
#    --name "arm-rippers" \
#    1337server/automatic-ripping-machine:latest

{
  virtualisation.oci-containers.containers."arm-rippers" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "1337server/automatic-ripping-machine:latest";
    ports = [ "8080:8080" ];
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
      "--privileged"
    ];
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
