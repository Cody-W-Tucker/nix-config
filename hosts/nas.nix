{
  config,
  lib,
  inputs,
  pkgs,
  self,
  ...
}:

{
  imports = [
    ../modules/system/base.nix
    # ../modules/server
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
  ];

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
    };
    "home" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/CBDD-BD07";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [ ];

  # Auto configure usb etc, when plugedin
  services.udisks2.enable = true;

  # Networking
  networking = {
    hostName = "nas";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
    };
    users.codyt = {
      home.stateVersion = "23.11";
      imports = [
        ../users/cody/server.nix
        inputs.nixos-secrets.homeModules.default
      ];
      home.enableNixpkgsReleaseCheck = false;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
