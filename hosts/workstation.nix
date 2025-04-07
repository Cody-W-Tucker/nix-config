{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/desktop
      ../modules/styles.nix
      ../modules/scripts
      ../modules/desktop/nvidia.nix
      ../modules/desktop/vpn.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "workstation"; # Define your hostname.

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" "ehci_pci" "usb_storage" ];
  boot.kernelModules = [ "kvm-intel" "btusb" "btintel" ];
  boot.extraModulePackages = [ ];
  time.hardwareClockInLocalTime = true;

  # Networking
  networking.networkmanager.enable = true;

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

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
      options = [ "nofail" ];
    };

  fileSystems."/home/codyt/Records" = {
    device = "/mnt/backup/Share/Records";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Business" = {
    device = "/mnt/backup/Share/Business";
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

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # To see trash and network shares in nautilus
  services.gvfs.enable = true;

  # Override Display Manager and Windowing system.
  services = {
    displayManager = {
      sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
    };
    autoLogin.user = "codyt";
    };
    xserver = {
      enable = true;
      displayManager.gdm.enable = lib.mkForce false;
      desktopManager.gnome.enable = lib.mkForce false;
      xkb = {
        layout = "us";
        model = "pc105";
      };
    };
  };

  # Getting keyring to work
  security = {
    polkit = {
      enable = true;
    };
    pam.services = {
      sddm.enableGnomeKeyring = true;
      login.enableGnomeKeyring = true;
    };
  };

  hardware.openrazer = {
    enable = true;
    devicesOffOnScreensaver = true;
    users = [ "codyt" ];
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      libvdpau-va-gl
      intel-media-sdk # Enable QSV
    ];
  };
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };

  # Setting the color theme and default wallpaper
  stylix.image = ../modules/wallpapers/galaxy-waves.jpg;
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
    ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    WAYLAND_DISPLAY = "wayland-0";
    # Qt Variables
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    MOZ_ENABLE_WAYLAND = "1";
    NVD_BACKEND = "direct";
  };

  services = {
    fwupd.enable = true;
    thermald.enable = true;
  };

  # Machine specific packages
  environment.systemPackages =
    (with pkgs; [
      # list of stable packages go here
      where-is-my-sddm-theme
      nvidia-vaapi-driver
    ]);


  # Virtualization
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["codyt"];
  virtualisation.spiceUSBRedirection.enable = true;

  # Nvidia PRIME
  hardware.nvidia.prime = {
    offload = {
			enable = true;
			enableOffloadCmd = true;
		};
		# Make sure to use the correct Bus ID values for your system!
		intelBusId = "PCI:0:2:0";
		nvidiaBusId = "PCI:1:0:0";
	};

  # Don't change this
  system.stateVersion = "24.05"; # Did you read the comment?
}
