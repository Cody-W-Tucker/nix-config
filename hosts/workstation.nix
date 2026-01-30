{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../configuration.nix
    ../modules/desktop
    ../modules/desktop/tailscale.nix
    ../modules/desktop/hyprland.nix
    ../modules/desktop/nvidia.nix
    ../modules/desktop/razer.nix
    ../modules/scripts
    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "workstation"; # Define your hostname.

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
    "ehci_pci"
    "usb_storage"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "btusb"
    "btintel"
    "sg"
  ];
  boot.extraModulePackages = [ ];
  time.hardwareClockInLocalTime = true;

  # Networking
  networking.networkmanager.enable = true;

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9e34e9a8-f360-45a6-b6e2-ceab59a207d9";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/DAAA-35C7";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/home/codyt/Documents" = {
    device = "/mnt/backup/Share/Documents";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/mnt/backup/Share/Music";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/mnt/backup/Share/Pictures";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/mnt/backup/Share/Videos";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Knowledge/Personal" = {
    device = "/mnt/backup/Obsidian";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Set the logging configuration for the machine
  services.promtail.configuration.scrape_configs = [
    {
      job_name = "journal";
      journal = {
        max_age = "12h";
        labels = {
          job = "systemd-journal";
          host = "workstation";
        };
      };
      relabel_configs = [
        {
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }
      ];
    }
  ];

  # Hardware config
  boot = {
    kernelParams = [
      # source https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1803179/comments/149
      "acpi_rev_override=1"
      "acpi_osi=Linux"
      "pcie_aspm=force"
      "drm.vblankoffdelay=1"
      "mem_sleep_default=deep"
      # fix flicker
      # source https://wiki.archlinux.org/index.php/Intel_graphics#Screen_flickering
      "i915.enable_psr=0"
      # Enables GuC submission for better GPU performance.
      "i915.enable_guc=2"
      # asynchronous page flipping
      "i915.enable_fbc=1"
      # nvidia stuff
      "nvidia_drm.fbdev=1"
    ];
  };

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "24.05"; # Did you read the comment?
}
