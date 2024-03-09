# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <home-manager/nixos>
    ];

  # Run the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Set up the X11 windowing system.
  services.xserver = {
    enable = true;
    displayManager = {
      autoLogin.enable = true;
      autoLogin.user = "codyt";
      sddm = {
        enable = true;
        wayland.enable = true;
        theme = "where_is_my_sddm_theme";
      };
    };
  };

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Trying to fix the issue with swaylock accepting password input
  security.pam.services.swaylock = {
    text = ''
    auth include login
    '';
  };

  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  #xdg  
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Enable OpenGL
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      ];
    };
    openrazer.enable = true;
    openrazer.devicesOffOnScreensaver = true;
    openrazer.users = [ "codyt" ];
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    packages = with pkgs; [
      xwaylandvideobridge
    ];
    shell = pkgs.zsh;
  };

  # Manage user environment with home-manager
  home-manager.users.codyt = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Add some packages to the user environment.
      dconf
      grim
      slurp
      wl-clipboard
      nodejs
      hyprpicker
      starship
    ];
    imports = [ ./modules/hyprland.nix ./modules/terminal.nix ./modules/xdg.nix ];
    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };
    };
    # X keyboard
    home.keyboard = {
      layout = "us";
      model = "pc104";
    };
    home.pointerCursor = {
      gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.gnome.adwaita-icon-theme;
        name = "Adwaita";
      };
      theme = {
        name = "WhiteSur-Dark-solid";
        package = pkgs.whitesur-gtk-theme;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme=1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme=1;
      };
    };
    home.sessionVariables = {
      GTK_THEME = "WhiteSur-Dark";
      BROWSER = "google-chrome";
      EDITOR = "nvim";
      VISUAL = "code";
      TERMINAL = "kitty";
      LIBVA_DRIVER_NAME = "iHD";
	    WLR_RENDERER = "vulkan";
      # GTK_USE_PORTAL = "1";
      NIXOS_OZONE_WL = "1";
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "23.11";
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      source-han-sans
      (nerdfonts.override { fonts = [ "Meslo"]; })
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "Meslo LG M Regular Nerd Font Complete Mono" ];
        serif = [ "Noto Serif" "Source Han Serif"];
        sansSerif = [ "Noto Sans" "Source Han Sans" ];
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
   git
   direnv
   waybar
   mako
   swww
   kitty
   rofi-wayland
   firefox
   google-chrome
   zoom-us
   vscode
   pywal
   ranger
   docker
   docker-compose
   docker-client
   pavucontrol
   hunspell
   gcalcli
   openrazer-daemon
   spotify
   xdg-utils # xdg-open
   hypridle
   hyprlock
   #wolfram-engine
   # wget
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ZSH settings
  programs.zsh.enable = true;

  # Thunar file manager
  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  # NeoVim
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  # Enabling auto enviroment switching per directory
  programs.direnv.enable = true;

  # Enable Docker.
  virtualisation.docker.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
