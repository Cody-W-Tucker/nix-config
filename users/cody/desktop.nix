{
  osConfig,
  pkgs,
  inputs,
  config,
  ...
}:

let
  inherit (osConfig.codyos.site) domain;
in
{
  sops.secrets."opencode-password" = { };

  imports = [
    ./core.nix
    ./desktop
    ./editor/nixvim/plugins/desktop.nix
    inputs.stylix.homeModules.stylix
  ];

  programs.zsh.autosuggestion.highlight = "fg=#${config.lib.stylix.colors.base04}";
  programs.zsh.shellAliases = {
    ssh- = "kitty +kitten ssh";
    copy = "kitten clipboard";
  };
  programs.kitty = {
    enable = true;
    settings = {
      remember_window_size = "no";
      auto_reload_config = "-1";
      shell_integration = "no-cursor";
      window_padding_width = "0 8";
      confirm_os_window_close = "0";
      wayland_titlebar_color = "system";
      cursor_shape = "block";
      enable_audio_bell = "no";
      cursor_trail = 1;
      cursor_trail_start_threshold = 3;
      cursor_trail_decay = "0.1 0.4";
      tab_bar_style = "powerline";
    };
  };

  # The NAS OpenCode server uses HTTP Basic auth. Scope its secret to the
  # explicit remote alias so regular `op` sessions remain local.
  programs.zsh.shellAliases.op- = ''
    OPENCODE_SERVER_PASSWORD="$(<${config.sops.secrets."opencode-password".path})" \
    opencode --server https://opencode.${domain}
  '';

  # Styling and themes
  # The GNOME target is disabled, but apps still need its color preference.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if config.stylix.polarity == "dark" then "prefer-dark" else "default";

  stylix = {
    enable = true;
    overlays.enable = false; # stop stylix from overriding nixpkgs
    polarity = "dark";
    targets = {
      nixvim.enable = false;
      gnome.enable = false;
      kde.enable = false;
      # Fully replaced by local config in desktop/{waybar,hyprland}.nix and core.nix.
      waybar.enable = false;
      hyprlock.enable = false;
      fzf.enable = false;
      # rofi.nix sets its own font; keep the target for theme colors.
      rofi.fonts.enable = false;
      firefox.profileNames = [ "default" ];
      zen-browser.profileNames = [ "Default Profile" ];
      kitty.fonts.override = {
        size = 16;
      };
    };
    opacity = {
      applications = 0.9;
      terminal = 0.8;
      desktop = 1.0;
      popups = 1.0;
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    fonts = {
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
    # Wallpaper
    image = ../../wallpapers/galaxy-waves.jpg;
  };

  home.packages = with pkgs; [
    inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Hermes Desktop: stay on native Wayland and the NVIDIA hardware path.
    # Vulkan is not compatible with Chromium's native Wayland ozone backend;
    # without this flag, Electron can repeatedly lose its GPU process. Hermes
    # then records that failure and reroutes subsequent launches to CPU-only
    # SwiftShader. Keep that recovery path off after removing Vulkan.
    (
      (inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop.override {
        extraEnv = {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          HERMES_DESKTOP_NVIDIA_SWIFTSHADER = "0";
        };
      }).overrideAttrs
        (old: {
          postFixup = (old.postFixup or "") + ''
            wrapProgram "$out/bin/hermes-desktop" \
              --add-flags "--disable-features=Vulkan"
          '';
        })
    )
    # Agent memory loop: backpass bundles `acpx` and `lavish-axi` as private
    # runtime dependencies on its own wrapper PATH.
    backpass
    libnotify # Notification library
    nautilus # File manager
    nixd # Nix daemon for development
    gcalcli # Google Calendar CLI tool
    feishin # Desktop app music player
    wttrbar # Weather bar for Waybar
    vesktop # Discord client
    rustdesk-flutter # Remote support into customer machines (public RustDesk servers)
    kdePackages.kpeople # Contact integration for KDE Connect SMS
    playerctl # MPRIS cli; also provides playerctld D-Bus activation
    tuxedo # TUI for tasks
    wl-clipboard # Clipboard manager for Wayland
    imagemagick # Image manipulation tools
    libsecret # Secret management library
  ];

  home.sessionVariables = {
    # ---------------------------
    # HDR Passthrough Support
    # ---------------------------
    DXVK_HDR = "1";
    ENABLE_HDR_WSI = "1";
    # ---------------------------
    # Electron and Browser Support
    # ---------------------------

    # Let Electron/Chromium apps use the native Wayland backend
    NIXOS_OZONE_WL = 1;

    # Enable Wayland backend for Firefox (and other Mozilla apps)
    MOZ_ENABLE_WAYLAND = "1";

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
    # Wayland & Compositor Settings
    # ---------------------------

    # Preferred GDK (GTK) backends (Wayland, fallback to X11)
    GDK_BACKEND = "wayland,x11";
    # SDL (Simple DirectMedia Layer) to use Wayland
    SDL_VIDEODRIVER = "wayland,x11";
    # Use libinput for input devices in wlroots compositors
    WLR_USE_LIBINPUT = "1";
  };
}
