{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ./configuration.nix
      ./modules/common/desktop
      ./modules/styles.nix
      ./modules/scripts
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "business-desktop";

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/c6c7b5c2-8edf-4aa5-9c6d-cbcd7498db1d";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/763D-AB92";
      fsType = "vfat";
    };

  fileSystems."/mnt/media" =
    {
      device = "/dev/disk/by-uuid/7e4d866f-4494-41c6-850b-a5dc2cd8367a";
      fsType = "ext4";
    };

  swapDevices = [ ];

  # Enable automatic login for the user.
  services.displayManager.autoLogin.user = "codyt";

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.docker0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.openrazer = {
    enable = true;
    devicesOffOnScreensaver = true;
    users = [ "codyt" ];
  };

  home.wayland.windowManager.hyprland.settings = {
    monitor = [
      "DP-2,2560x1080@60,0x0,1"
      "DP-1,2560x1080@60,0x1080,1"
    ];
    workspace = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-2, default:true"
    ];
  };

  home.programs.waybar.settings = {
    # Duplicate the bars for each monitor
    monitor1 = createBar waybarConfig "DP-2" "bottom";
    monitor2 = createBar waybarConfig "DP-1" "top";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
