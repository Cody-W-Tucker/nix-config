{ pkgs, ... }:

{
  programs.nixvim.plugins.startup = {
    enable = true;
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
