{ config, lib, pkgs, pkgs-unstable, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/desktop
      ../modules/desktop/nvidia.nix
      ../modules/desktop/gaming.nix
      ../modules/desktop/hyprland.nix
      ../modules/scripts
      ../modules/desktop/mcp-servers.nix
      ../modules/server/ai.nix
    ];

  config = {

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    boot.initrd.availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    boot.kernelModules = [ "kvm-intel" ];
    time.hardwareClockInLocalTime = true;

    # Networking
    networking.hostName = "beast"; # Define your hostname.
    networking.networkmanager.enable = true;
    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    networking.useDHCP = lib.mkDefault true;

    # Use the latest kernel and matching NVIDIA driver
    boot.kernelPackages = pkgs-unstable.linuxPackages_zen;
    hardware.nvidia.package = lib.mkForce pkgs-unstable.linuxKernel.packages.linux_zen.nvidia_x11_beta;

    # Performance Tweaks
    powerManagement.cpuFreqGovernor = "performance";

    # Ensure 14th Gen Intel CPU works correctly
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # System Filesystems
    fileSystems."/" =
      {
        device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
        fsType = "ext4";
        options = [ "noatime" ];
      };

    fileSystems."/boot" =
      {
        device = "/dev/disk/by-uuid/36FA-44EF";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

    # Sync configuration for user directories
    services.syncthing = {
      user = "codyt";
      group = "users";
      configDir = "/home/codyt/.config/syncthing";
      settings.folders = {
        "share" = {
          path = "/mnt/backup/Share";
          devices = [ "server" "workstation" ];
        };
        "Cody's Obsidian" = {
          path = "/home/codyt/Sync/Cody-Obsidian";
          devices = [ "Cody's Pixel" ];
        };
      };
    };

    # User home directories
    fileSystems."/home/codyt/Records" = {
      device = "/mnt/backup/Share/Records";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    fileSystems."/home/codyt/Documents" = {
      device = "/mnt/backup/Share/Documents";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    fileSystems."/home/codyt/Music" = {
      device = "/mnt/backup/Share/Music";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    fileSystems."/home/codyt/Pictures" = {
      device = "/mnt/backup/Share/Pictures";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    fileSystems."/home/codyt/Videos" = {
      device = "/mnt/backup/Share/Videos";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    fileSystems."/home/codyt/Sync/Cody-Obsidian" = {
      device = "/mnt/backup/Share/Documents/Personal";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

    swapDevices = [ ];

    # Getting keyring to work
    security = {
      polkit = {
        enable = true;
      };
      pam.services = {
        login.enableGnomeKeyring = true;
      };
    };

    # Machine specific packages
    environment.systemPackages =
      (with pkgs; [
        rofi-network-manager
      ]);

    # Ensure headset doesn't switch profiles
    services.pipewire.wireplumber.extraConfig."11-bluetooth-policy" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "25.05"; # Did you read the comment?
  };
}
