{ config, pkgs, ... }:
let
  overlay = final: prev: {
    handbrake = prev.handbrake.override {
      useQsv = true;
      useGTK = false;
      useFdk = false;
    };
  };
in

{
  # Overlay to build handbrake with QSV support
  nixpkgs.overlays = [ overlay ];

  environment.systemPackages = with pkgs; [
    # Handbrake with QSV support
    handbrake
  ];

  # Export the environment variable to use the iHD driver
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # Installing the graphics drivers
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      vaapiVdpau
      libvdpau-va-gl
      intel-media-sdk # QSV up to 11th gen
    ];
  };

  # I needed to add the boot.kernelModules line to allow the container to see the disk drive.
  boot.kernelModules = [ "sg" ];

  # Open the port of the webui
  networking.firewall.allowedTCPPorts = [ 9090 ];

  # Set the container for ARM
  virtualisation.oci-containers.containers."arm-rippers" = {
    autoStart = true; # Assuming you want the container to start automatically on boot
    image = "automaticrippingmachine/automatic-ripping-machine:latest";
    ports = [ "9090:8080" ]; #TODO: Change the port to something other than 8080, might have to change env var also
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
      "/run/udev:/run/udev:ro"
    ];
    extraOptions = [
      "--device=/dev/sr0:/dev/sr0"
      "--device=/dev/dri:/dev/dri"
      "--privileged"
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
