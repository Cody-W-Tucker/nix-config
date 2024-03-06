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

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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

  # Enable the GNOME Desktop Environment.
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  #polkit Auth Agent
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
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
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
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
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    openrazer.enable = true;
    openrazer.devicesOffOnScreensaver = true;
    openrazer.users = [ "codyt" ];
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

  # ZSH settings
  programs.zsh.enable = true;

  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  #xdg  
  xdg.portal = {
    enable = true;
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
    imports = [ ./modules/hyprland.nix ./modules/terminal.nix ];
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
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
      # BROWSER = "google-chrome-stable";
      EDITOR = "nvim";
      VISUAL = "code";
      TERMINAL = "kitty";
      LIBVA_DRIVER_NAME = "iHD";
	    WLR_RENDERER = "vulkan";
      # GTK_USE_PORTAL = "1";
      XDG_CACHE_HOME = "\${HOME}/.cache";
	    XDG_CONFIG_HOME = "\${HOME}/.config";
      NIXOS_OZONE_WL = "1";
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "23.11";
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "codyt";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
   wlogout
   swaylock-effects
   swayidle
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
   libreoffice-qt
   hunspell
   gcalcli
   openrazer-daemon
   spotify
   xdg-utils # xdg-open
   #wolfram-engine
   # wget
  ];

  # Security daemon for swaylock, needed to make password input work
  security.pam.services.swaylock = {};

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

  # Once I figure this out I might want to start bytebase docker container on boot
  # I need a postgres database for it to connect to, so I'll use the postgres container for that
  # https://nixos.wiki/wiki/Docker
  # https://mynixos.com/options/virtualisation.oci-containers.containers.%3Cname%3E
  #   virtualisation.oci-containers = {
  #   backend = "docker";
  #   containers = {
  #     foo = {
  #       # ...
  #     };
  #   };
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 57621 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
