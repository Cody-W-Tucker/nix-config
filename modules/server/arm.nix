{
  # Load the 'sg' kernel module to allow the container to see disk drives
  boot.kernelModules = [ "sg" ];

  # Open port 9090 for the web UI of the container
  # networking.firewall.allowedTCPPorts = [ 9090 ];

  # Create a user 'arm' for the container; set the password with `passwd`
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "render" "docker" ];
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
  };

  # Create a group 'arm' for the container
  users.groups.arm = { };

  services.nginx.virtualHosts."arm.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/".proxyPass = "http://localhost:9090";
    kTLS = true;
  };

  # Configure the ARM container
  virtualisation.oci-containers.containers."arm-rippers" = {
    autoStart = true; # Automatically start the container on boot
    image = "custom-arm"; # custom ARM image with handbrake built with intelQSV support. After building the image run docker commit <container_id> custom-arm.
    ports = [ "9090:8080" ]; # Map host port 9090 to container port 8080
    environment = {
      ARM_UID = "1002"; # UID of the 'arm' user on the host system
      ARM_GID = "983"; # GID of the 'arm' group on the host system
    };
    # Mount 'host directory' to 'container directory'
    volumes = [
      "/home/arm:/home/arm"
      "/home/arm/Music:/home/arm/Music"
      "/home/arm/logs:/home/arm/logs"
      "/home/arm/media:/home/arm/media"
      "/home/arm/config:/etc/arm/config"
    ];
    # For IntelQSV support, add the GPU device to the container and follow the IntelQSV instructions in the ARM wiki at https://github.com/automatic-ripping-machine/automatic-ripping-machine/wiki/intel-qsv.
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--device=/dev/dri:/dev/dri"
      "--privileged"
    ];
  };
  # Service to keep arm-rippers updated
  systemd.services.restart-arm-rippers = {
    description = "Restart arm-rippers service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "systemctl restart docker-arm-rippers.service";
    };
  };
  systemd.timers.restart-arm-rippers = {
    wantedBy = [ "timers.target" ];
    partOf = [ "restart-arm-rippers.service" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 02:00:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };
}
