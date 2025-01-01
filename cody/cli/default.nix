{ config, pkgs, pkgs-unstable, inputs, lib, ... }:

{
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./nixvim.nix
  ];

  home.packages =
    (with pkgs; [
      # list of stable packages go here
      gh
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
    ]);

  # User specific terminal settings
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
    };
  };

  programs = {
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      history.size = 10000;
      shellAliases = {
        ssh = "kitty +kitten ssh";
        ll = "ls -l";
        copy = "kitten clipboard";
        pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
        update = ''
          cd /etc/nixos &&
          git add . &&
          git commit -m "Pre-update commit" &&
          sudo nixos-rebuild switch &&
          git push
        '';
        upgrade = ''
          cd /etc/nixos &&
          sudo nix flake update
          sudo nixos-rebuild switch
        '';
        gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
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
}
