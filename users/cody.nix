{ pkgs, config, inputs, lib, nixvim, ... }:

{
  imports = [
    ./cody
    inputs.hyprland.homeManagerModules.default
    inputs.nixvim.homeManagerModules.nixvim
  ];
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };

  # User specific terminal settings
  programs = {
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      history.size = 10000;
      shellAliases = {
        ssh = "kitty +kitten ssh";
      };
    };
    bash = {
      historyFile = "${config.xdg.dataHome}/bash/bash_history";
    };
    direnv = {
      enable = true;
    };
    fzf = {
      enable = true;
    };
    kitty = {
      enable = true;
      settings = {
        shell_integration = "no-cursor";
        window_padding_width = "0 8";
        confirm_os_window_close = "0";
        wayland_titlebar_color = "system";
        cursor_shape = "block";
      };
      extraConfig = lib.mkForce ''
        foreground #${config.lib.stylix.colors.base05}
        background #${config.lib.stylix.colors.base00}
        color0  #${config.lib.stylix.colors.base03}
        color1  #${config.lib.stylix.colors.base08}
        color2  #${config.lib.stylix.colors.base0B}
        color3  #${config.lib.stylix.colors.base09}
        color4  #${config.lib.stylix.colors.base0D}
        color5  #${config.lib.stylix.colors.base0E}
        color6  #${config.lib.stylix.colors.base0C}
        color7  #${config.lib.stylix.colors.base06}
        color8  #${config.lib.stylix.colors.base04}
        color9  #${config.lib.stylix.colors.base08}
        color10 #${config.lib.stylix.colors.base0B}
        color11 #${config.lib.stylix.colors.base0A}
        color12 #${config.lib.stylix.colors.base0C}
        color13 #${config.lib.stylix.colors.base0E}
        color14 #${config.lib.stylix.colors.base0C}
        color15 #${config.lib.stylix.colors.base07}
        color16 #${config.lib.stylix.colors.base00}
        color17 #${config.lib.stylix.colors.base0F}
        color18 #${config.lib.stylix.colors.base0B}
        color19 #${config.lib.stylix.colors.base09}
        color20 #${config.lib.stylix.colors.base0D}
        color21 #${config.lib.stylix.colors.base0E}
        color22 #${config.lib.stylix.colors.base0C}
        color23 #${config.lib.stylix.colors.base06}
        cursor  #${config.lib.stylix.colors.base07}
        cursor_text_color #${config.lib.stylix.colors.base00}
        selection_foreground #${config.lib.stylix.colors.base01}
        selection_background #${config.lib.stylix.colors.base0D}
        url_color #${config.lib.stylix.colors.base0C}
        active_border_color #${config.lib.stylix.colors.base04}
        inactive_border_color #${config.lib.stylix.colors.base00}
        bell_border_color #${config.lib.stylix.colors.base03}
        tab_bar_style fade
        tab_fade 1
        active_tab_foreground   #${config.lib.stylix.colors.base04}
        active_tab_background   #${config.lib.stylix.colors.base00}
        active_tab_font_style   bold
        inactive_tab_foreground #${config.lib.stylix.colors.base07}
        inactive_tab_background #${config.lib.stylix.colors.base08}
        inactive_tab_font_style bold
        tab_bar_background #${config.lib.stylix.colors.base00}
      '';
    };
  };

  # Theme GTK
  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };

  home.sessionVariables = {
    BROWSER = "google-chrome";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    VDPAU_DRIVER = "va_gl";
    NIXOS_OZONE_WL = 1;
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    MOZ_ENABLE_WAYLAND = "1";
    # LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    # GBM_BACKEND = "nvidia-drm";
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # NVD_BACKEND = "direct";
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
