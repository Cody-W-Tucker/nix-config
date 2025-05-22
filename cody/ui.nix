{ config, lib, ... }:

{
  imports = [
    ./ui
    ./cli
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };

  home.sessionVariables.CUDA_CACHE_PATH = "\${HOME}/.cache/nv";

  # User specific terminal settings
  programs.kitty = {
    settings = {
      cursor_trail = 1;
      cursor_trail_start_threshold = 3;
      cursor_trail_decay = "0.1 0.4";
      tab_bar_style = "powerline";
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

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
