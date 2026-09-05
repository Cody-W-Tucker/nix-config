{ pkgs, ... }:

{
  programs.nixvim.plugins.startup = {
    enable = true;
    # Upstream defers an unconditional `nvim_win_set_cursor(0, {2,2})` 1ms
    # after display (init.lua:566). A keypress opening Telescope in that
    # window then errors "Invalid cursor line: out of range". The guard patch
    # below no-ops the callback unless the startup buffer is still current
    # and line 2 exists, so mappings need no artificial delay.
    package = pkgs.vimPlugins.startup-nvim.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./startup-cursor-guard.patch ];
    });
    settings = {
      header = {
        type = "text";
        oldfilesDirectory = false;
        align = "center";
        foldSection = false;
        title = "Header";
        margin = 5;
        # Use https://fsymbols.com/generators/carty/ to create this word art
        content = [
          "░█████╗░░█████╗░██████╗░██╗░░░██╗  ░██╗░░░░░░░██╗░█████╗░░██████╗  ██╗░░██╗███████╗██████╗░███████╗"
          "██╔══██╗██╔══██╗██╔══██╗╚██╗░██╔╝  ░██║░░██╗░░██║██╔══██╗██╔════╝  ██║░░██║██╔════╝██╔══██╗██╔════╝"
          "██║░░╚═╝██║░░██║██║░░██║░╚████╔╝░  ░╚██╗████╗██╔╝███████║╚█████╗░  ███████║█████╗░░██████╔╝█████╗░░"
          "██║░░██╗██║░░██║██║░░██║░░╚██╔╝░░  ░░████╔═████║░██╔══██║░╚═══██╗  ██╔══██║██╔══╝░░██╔══██╗██╔══╝░░"
          "╚█████╔╝╚█████╔╝██████╔╝░░░██║░░░  ░░╚██╔╝░╚██╔╝░██║░░██║██████╔╝  ██║░░██║███████╗██║░░██║███████╗"
          "░╚════╝░░╚════╝░╚═════╝░░░░╚═╝░░░  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═════╝░  ╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚══════╝"
        ];
        highlight = "Statement";
        defaultColor = "";
        oldfilesAmount = 0;
      };

      body = {
        type = "mapping";
        oldfilesDirectory = false;
        align = "center";
        foldSection = false;
        title = "Menu";
        margin = 5;
        content = [
          [
            " Find File"
            "Telescope find_files"
            "ff"
          ]
          [
            "󰍉 Find Word"
            "Telescope live_grep"
            "fg"
          ]
          [
            " Recent Files"
            "Telescope oldfiles"
            "fo"
          ]
          [
            " File Browser"
            "Yazi"
            "-"
          ]
        ];
        highlight = "string";
        defaultColor = "";
        oldfilesAmount = 0;
      };

      options = {
        paddings = [
          1
          3
        ];
      };

      parts = [
        "header"
        "body"
      ];
    };
  };
}
