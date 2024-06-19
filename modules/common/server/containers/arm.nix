{ config, pkgs, ... }:
{
  virtualisation.oci-containers.containers."automatic-ripping-machine" = {
    image = pkgs.dockerTools.buildImage {
      name = "automatic-ripping-machine";
      tag = "latest";
      contents = [
        { type = "path"; value = ./automatic-ripping-machine; }
      ];
    };
    ports = [ "8080:8080" ];
    extraOptions = [
      "--env=ARM_UID=$(id -u arm)"
      "--env=ARM_GID=$(id -g arm)"
      "--volume=/home/arm:/home/arm"
      "--volume=/home/arm/Music:/home/arm/Music"
      "--volume=/home/arm/logs:/home/arm/logs"
      "--volume=/home/arm/media:/home/arm/media"
      "--volume=/etc/arm/config:/etc/arm/config"
      "--device=/dev/sr0:/dev/sr0"
      "--device=/dev/sr1:/dev/sr1"
      "--device=/dev/sr2:/dev/sr2"
      "--device=/dev/sr3:/dev/sr3"
      "--privileged"
    ];
    restartPolicy = "always";
    memoryLimit = "1G";
  };
}
