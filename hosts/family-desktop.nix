{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/desktop
      ../modules/styles.nix
      ../modules/scripts
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "family"; # Define your hostname.

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "firewire_ohci" "usb_storage" "usbhid" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Networking
  networking.networkmanager.enable = true;

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/d6c24696-cc34-4a07-a065-9f143a63db02";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/A12C-B557";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 24 * 1024;
  }];

  # Enable automatic login for the user.
  services.displayManager.autoLogin.user = "jordant";

  users.users.jordant = {
    isNormalUser = true;
    description = "Jordan Tucker";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    # hashedPasswordFile = config.sops.secrets.jordant.path;
    hashedPassword = "$y$j9T$T1YkmagP6ULuI6DvQz8IK0$38YlfZN9eR1jH286/9kZn13flzy.wFtPX74ukXKJhM7";
    packages = with pkgs; [
      # thunderbird
      krita
    ];
  };

  # Enables DHCP on each ethernet and wireless interface.
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  # Setting the color theme and default wallpaper
  stylix.image = ../modules/wallpapers/Dancer.png;

  # Don't change this
  system.stateVersion = "24.05"; # Did you read the comment?
}
