{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../configuration.nix
    ../modules/server
    ../modules/server/tailscale.nix
    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "server";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "i915"
  ];
  boot.kernelParams = [ "i915.enable_guc=2" ];
  boot.extraModulePackages = [ ];

  # Networking
  networking.networkmanager.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/c6c7b5c2-8edf-4aa5-9c6d-cbcd7498db1d";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/763D-AB92";
    fsType = "vfat";
  };

  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/27ddc2ef-8f21-401d-b9eb-3ed4541c16c9";
    fsType = "ext4";
  };

  fileSystems."/mnt/dev/sr0" = {
    device = "/dev/sr0";
    fsType = "udf,iso9660";
    options = [
      "users"
      "noauto"
      "exec"
      "utf8"
    ];
  };

  swapDevices = [ ];

  # Auto configure usb etc, when plugedin
  services.udisks2.enable = true;
  security.polkit.enable = true;

  # NFS server for sharing media directory
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/media *(rw,sync,no_subtree_check)
  '';

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Don't change this
  system.stateVersion = "23.11"; # Did you read the comment?
}
