{ config, lib, pkgs, modulesPath, inputs, stylix, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/desktop
      ../modules/styles.nix
      ../modules/scripts
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "workstation"; # Define your hostname.

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" "btusb" ];
  boot.extraModulePackages = [ ];
  time.hardwareClockInLocalTime = true;

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.supportedFilesystems = [ "ntfs" ];
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

  fileSystems."/mnt/local-share" =
    {
      device = "/dev/disk/by-uuid/B466DF5B66DF1D44";
      fsType = "ntfs-3g";
      options = [ "rw" "uid=1000" ];
    };

  fileSystems."/mnt/backup" =
    {
      device = "/dev/disk/by-uuid/9dc55264-1ade-4f7b-a157-60d022feec40";
      fsType = "ext4";
    };

  fileSystems."/home/codyt/Records" = {
    device = "/mnt/backup/Share/Records";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Business" = {
    device = "/mnt/backup/Share/Business";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Documents" = {
    device = "/mnt/backup/Share/Documents";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/mnt/backup/Share/Music";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/mnt/backup/Share/Pictures";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/mnt/backup/Share/Videos";
    fsType = "none";
    options = [ "bind" ];
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  services.displayManager.autoLogin.enable = lib.mkForce false;

  # Getting Hyprlock and keyring to work
  security.pam.services = {
    hyprlock = { };
    greetd.enableGnomeKeyring = true;
    gdm-password.enableGnomeKeyring = true;
  };
  environment.variables.XDG_RUNTIME_DIR = "/run/user/$UID"; # set the runtime directory
  hardware.openrazer = {
    enable = true;
    devicesOffOnScreensaver = true;
    users = [ "codyt" ];
  };

  # Setting the color theme and default wallpaper
  stylix.image = ../modules/wallpapers/lone-figure.jpg;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

  # Backup configuration
  services.syncthing = {
    user = "codyt";
    group = "users";
    settings.folders = {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [ "server" "workstation" ];
      };
      "media" = {
        path = "/mnt/backup/Media";
        devices = [ "server" "workstation" ];
      };
      "photos" = {
        path = "/mnt/backup/Photos";
        devices = [ "server" "workstation" ];
      };
      "Cody's Obsidian" = {
        path = "/home/codyt/Sync/Cody-Obsidian";
        devices = [ "workstation" "Cody's Pixel" ];
      };
    };
  };

  # Open port for Loki
  networking.firewall.allowedTCPPorts = [ 9002 ];

  # Monitoring configuration
  services = {
    prometheus = {
      enable = true;
      port = 9001;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
    };

    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [{
          url = "http://server:3090/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "workstation";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };
  };

  # Hardware config
  boot = {
    kernelParams = [
      # fix lspci hanging with nouveau
      # source https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1803179/comments/149
      "acpi_rev_override=1"
      "acpi_osi=Linux"
      "nouveau.modeset=0"
      "pcie_aspm=force"
      "drm.vblankoffdelay=1"
      "nouveau.runpm=0"
      "mem_sleep_default=deep"
      # fix flicker
      # source https://wiki.archlinux.org/index.php/Intel_graphics#Screen_flickering
      "i915.enable_psr=0"
      "nvidia_drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [ nvidia-vaapi-driver ];
    };
    nvidia = {
      open = true;
      nvidiaSettings = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  services = {
    fwupd.enable = true;
    thermald.enable = true;
  };

  # Don't change this
  system.stateVersion = "24.05"; # Did you read the comment?
}
