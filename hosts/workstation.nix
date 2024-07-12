{ config, lib, pkgs, modulesPath, inputs, stylix, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/common/desktop
      ../modules/styles.nix
      ../modules/scripts
      ../modules/nvidia.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "workstation"; # Define your hostname.

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "nvidia" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  time.hardwareClockInLocalTime = true;

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/9e34e9a8-f360-45a6-b6e2-ceab59a207d9";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/DAAA-35C7";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/mnt/backup" =
    {
      device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40";
      fsType = "ext4";
    };

  fileSystems."/home/codyt/Records" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Records";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Business" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Business";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Documents" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Documents";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Music";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Pictures";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40/Share/Videos";
    fsType = "none";
    options = [ "bind" ];
  };

  swapDevices = [ ];

  # Enable automatic login for the user.
  services.displayManager.autoLogin.user = "codyt";

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.openrazer = {
    enable = true;
    devicesOffOnScreensaver = true;
    users = [ "codyt" ];
  };

  # Setting the color theme and default wallpaper
  stylix.image = config.lib.stylix.pixel "base0A";
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";

  # hardware.nvidia.prime = {
  #   intelBusId = "PCI:0:2:0";
  #   nvidiaBusId = "PCI:1:0:0";
  # };

  # Backup configuration
  services.syncthing.user = "codyt";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
