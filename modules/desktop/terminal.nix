{
  # Kitty terminal (the default $TERMINAL) and its shell aliases.
  den.aspects.terminal.provides.to-users.homeManager = {
    home.sessionVariables.TERMINAL = "kitty";

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
  };
}
