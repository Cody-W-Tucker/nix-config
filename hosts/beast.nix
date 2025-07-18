{ inputs, config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      ../configuration.nix
      ../modules/desktop
      ../modules/desktop/nvidia.nix
      ../modules/scripts
      ../modules/desktop/mcp-servers.nix
      ../modules/server/ai.nix
    ];

  config = {

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    networking.hostName = "beast"; # Define your hostname.

    boot.initrd.availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];
    boot.kernelParams = [
      # Solves Nvidia TTY issues
      "nvidia_drm.fbdev=1"
      # Sets resolution for monitors during load
      "video=DP-1:2560x1440@239.97"
      "video=DP-3:2560x1080@60"
      "video=HDMI-A-3:2560x1080@60"
    ];
    time.hardwareClockInLocalTime = true;

    # Networking
    networking.networkmanager.enable = true;

    # Use the latest kernel
    boot.kernelPackages = pkgs.linuxPackages_zen;

    fileSystems."/" =
      {
        device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
        fsType = "ext4";
      };

    fileSystems."/boot" =
      {
        device = "/dev/disk/by-uuid/36FA-44EF";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

    # Backup configuration
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

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # To see trash and network shares in nautilus
    services.gvfs.enable = true;

    # Override Display Manager and Windowing system.
    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "uwsm start hyprland-uwsm.desktop";
            user = "codyt";
          };
        };
        vt = 2;
      };
      displayManager = {
        autoLogin.enable = lib.mkForce false;
      };
      xserver = {
        enable = lib.mkForce false;
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

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
      ];
    };

    # Gaming Configuration
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
    programs.gamemode.enable = true;

    environment.sessionVariables = {
      # ---------------------------
      # Electron and Browser Support
      # ---------------------------

      # Force Electron apps to use X11 backend
      NIXOS_OZONE_WL = 1;

      # Enable Wayland backend for Firefox (and other Mozilla apps)
      MOZ_ENABLE_WAYLAND = "1";
      # Disable RDD sandbox in Mozilla (may help with Nvidia or video decoding issues)
      MOZ_DISABLE_RDD_SANDBOX = "1";

      # ---------------------------
      # Qt Toolkit Configuration
      # ---------------------------

      # Automatically scale Qt apps based on screen DPI
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      # Use Wayland as the Qt platform
      QT_QPA_PLATFORM = "wayland;xcb";
      # Disable window decorations in Qt on Wayland
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # ---------------------------
      # Nvidia & Graphics Drivers
      # ---------------------------

      # Use Nvidia driver for VA-API (hardware video decoding)
      LIBVA_DRIVER_NAME = "nvidia";
      # Set Nvidia backend for NVDEC/NVENC
      NVD_BACKEND = "direct";
      # Use Nvidia GBM backend for DRM (Direct Rendering Manager)
      GBM_BACKEND = "nvidia-drm";
      # Use Nvidia's GLX implementation
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = "1";

      # ---------------------------
      # Wayland & Compositor Settings
      # ---------------------------

      # Preferred GDK (GTK) backends (Wayland, fallback to X11)
      GDK_BACKEND = "wayland,x11";
      # SDL (Simple DirectMedia Layer) to use Wayland
      SDL_VIDEODRIVER = "wayland,x11";
      # Use libinput for input devices in wlroots compositors
      WLR_USE_LIBINPUT = "1";
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
        egl-wayland
        inputs.web-downloader.packages.${pkgs.system}.default
        cifs-utils
        gamescope-wsi
        # HDR support packages
        vkd3d
      ]);

    programs.command-not-found.enable = true;

    # Ensure headset doesn't switch profiles
    services.pipewire.wireplumber.extraConfig."11-bluetooth-policy" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };

    # Use mullvad VPN for external traffic
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
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
