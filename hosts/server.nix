{ config, lib, pkgs, modulesPath, inputs, stylix, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/server
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "server";

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "i915" ];
  boot.kernelParams = [ "i915.enable_guc=2" ];
  boot.extraModulePackages = [ ];

  # Networking
  networking.networkmanager.enable = true;

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

  fileSystems."/mnt/hdd" =
    {
      device = "/dev/disk/by-uuid/7e4d866f-4494-41c6-850b-a5dc2cd8367a";
      fsType = "ext4";
    };

  fileSystems."/mnt/dev/sr0" =
    {
      device = "/dev/sr0";
      fsType = "udf,iso9660";
      options = [ "users" "noauto" "exec" "utf8" ];
    };

  swapDevices = [ ];

  # Create user groups for different services
  users.groups.media = { };

  # Auto configure usb etc, when plugedin
  services.udisks2.enable = true;
  services.polkit.enable = true;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Don't change this
  system.stateVersion = "23.11"; # Did you read the comment?
}
