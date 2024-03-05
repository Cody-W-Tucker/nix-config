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
    # openrazer.users = [ "codyt" ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    packages = with pkgs; [
      xwaylandvideobridge
    ];
  };

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
    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = ''
        monitor=DP-2,2560x1080@60,0x0,1
        monitor=DP-1,2560x1080@60,0x1080,1
        animations {
          enabled = yes
          bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
        }
        exec-once = /home/codyt/Code/dotfiles/scripts/sleep.sh
        exec-once = waybar
        exec-once = mako
        exec-once = swww init
        exec-once = /home/codyt/Code/dotfiles/scripts/wallpaper.sh ~/Pictures/Wallpapers
      '';
      settings = {
        input = {
          numlock_by_default = "true";
          follow_mouse = "1";
          sensitivity = "-.7";
          kb_model = "pc104";
          kb_layout = "us";
        };
        general =  {
          border_size = "2";
          gaps_in = "5";
          gaps_out = "20";
          layout = "master";
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
        };
        decoration = {
          rounding = "10";
          blur = {
            enabled = "true";
            size = "3";
            passes = "1";
            new_optimizations = "true";
          };
        drop_shadow = "yes";
        shadow_range = "4";
        shadow_render_power = "3";
        "col.shadow" = "rgba(1a1a1aee)";
        };
        dwindle = {
          pseudotile = "yes";
          preserve_split = "yes";
        };
        master = {
          new_is_master = "true";
        };
        gestures = {
          workspace_swipe = "off";
        };
        misc = {
          mouse_move_enables_dpms = "true";
          key_press_enables_dpms = "true";
          force_default_wallpaper = "0";
        };
        # Keybindings
        "$mainMod" = "SUPER";
        bindm = [
            # Move/resize windows with mainMod + LMB/RMB and dragging
            "$mainMod, mouse:272, movewindow"
            "$mainMod, mouse:273, resizewindow"
          ];
        bind =
          [
            "$mainMod, RETURN, exec, pkill waybar && waybar &"
            "$mainMod, ESCAPE, exec, wlogout"
            "$mainMod, Q, exec, kitty"
            "$mainMod, C, killactive"
            "$mainMod, E, exec, nautilus"
            "$mainMod, V, togglefloating"
            "$mainMod, Tab, exec, rofi -show drun -show-icons"
            "$mainMod, F, fullscreen"
            "$mainMod SHIFT, F, fakefullscreen"
            # Number keys (0, -, +)
            "$mainMod, KP_Insert, exec, google-chrome-stable --app=https://chat.openai.com"
            "$mainMod, KP_Add, exec, hyprctl dispatch exec [floating] gnome-calculator"
            "$mainMod, KP_Enter, exec, google-chrome-stable --app=https://essay.app/home/"
            "$mainMod, KP_Subtract, exec, google-chrome-stable --app=https://recorder.google.com/"
            # Number keys (1, 2, 3)
            "$mainMod, KP_End, exec, google-chrome-stable --app=https://mail.google.com"
            "$mainMod, KP_Down, exec, google-chrome-stable --app=https://messages.google.com/web/u/0/conversations"
            "$mainMod, KP_Next, exec, google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r"
            # Number keys (4, 5, 6)
            "$mainMod, KP_Left, exec, google-chrome-stable --app=https://app.asana.com/home"
            "$mainMod, KP_Begin, exec, google-chrome-stable --app=https://app.reclaim.ai/planner?taskSort=schedule"
            "$mainMod, KP_Right, exec, google-chrome-stable --app=https://tmvsocial.harvestapp.com/projects?filter=active"
            # Number keys (7, 8, 9)
            "$mainMod, KP_Home, exec, code"
            # Skipped 8 KP_Up
            "$mainMod, KP_Prior, exec, google-chrome-stable --app=https://tmv-social.odoo.com/web?action=277&model=account.journal&view_type=kanban&cids=1&menu_id=114"
            # Screenshots
            ''$mainMod, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date '+%y%m%d_%H-%M-%S').png"''
            ''$mainMod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
            # Move focus with mainMod + arrow keys
            "$mainMod, left, movefocus, l"
            "$mainMod, right, movefocus, r"
            "$mainMod, up, movefocus, u"
            "$mainMod, down, movefocus, d"
            # Move windows with mainMod + shift + arrow keys
            "$mainMod SHIFT, left, movewindow, l"
            "$mainMod SHIFT, right, movewindow, r"
            "$mainMod SHIFT, up, movewindow, u"
            "$mainMod SHIFT, down, movewindow, d"
            # Special workspace (scratchpad)
            "$mainMod, A, togglespecialworkspace, magic"
            "$mainMod SHIFT, A, movetoworkspacesilent, special:magic"
            # Hyprpicker color picker
            "$mainMod, mouse:274, exec, hyprpicker -a"
          ]
          ++ (
            # workspaces
            # binds $mainMod + [shift +] {1..9} to [move to] workspace {1..9}
            builtins.concatLists (builtins.genList (
                x: let
                  ws = let
                    c = (x + 1) / 10;
                  in
                    builtins.toString (x + 1 - (c * 10));
                in [
                  "$mainMod, ${ws}, workspace, ${toString (x + 1)}"
                  "$mainMod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
                ]
              )
              10)
          );
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
    programs.bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        eval "$(direnv hook bash)"
        eval "$(starship init bash)"
        export PATH=$HOME/.npm-global/bin:$PATH
      '';
    };
    programs.starship = {
      enable = true;
    };
    programs.kitty = {
      enable = true;
      # theme = "OneHalfDark";
      font = {
        name = "MesloLGSDZ Nerd Font Mono";
        size = 12;
      };
      settings = {
        "window_padding_width" = "0 8";
        "confirm_os_window_close" = "0";
        "background_opacity" = ".8";
        "wayland_titlebar_color" = "system";
      };
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
