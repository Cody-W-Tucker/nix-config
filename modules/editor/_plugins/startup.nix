{ pkgs, ... }:
let
  section = {
    oldfilesDirectory = false;
    align = "center";
    foldSection = false;
    margin = 5;
    defaultColor = "";
    oldfilesAmount = 0;
  };
in
{
  programs.nixvim.plugins.startup = {
    enable = true;
    package = pkgs.vimPlugins.startup-nvim.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./startup-cursor-guard.patch ];
    });
    settings = {
      header = section // {
        type = "text";
        title = "Header";
        content = [
          "░█████╗░░█████╗░██████╗░██╗░░░██╗  ░██╗░░░░░░░██╗░█████╗░░██████╗  ██╗░░██╗███████╗██████╗░███████╗"
          "██╔══██╗██╔══██╗██╔══██╗╚██╗░██╔╝  ░██║░░██╗░░██║██╔══██╗██╔════╝  ██║░░██║██╔════╝██╔══██╗██╔════╝"
          "██║░░╚═╝██║░░██║██║░░██║░╚████╔╝░  ░╚██╗████╗██╔╝███████║╚█████╗░  ███████║█████╗░░██████╔╝█████╗░░"
          "██║░░██╗██║░░██║██║░░██║░░╚██╔╝░░  ░░████╔═████║░██╔══██║░╚═══██╗  ██╔══██║██╔══╝░░██╔══██╗██╔══╝░░"
          "╚█████╔╝╚█████╔╝██████╔╝░░░██║░░░  ░░╚██╔╝░╚██╔╝░██║░░██║██████╔╝  ██║░░██║███████╗██║░░██║███████╗"
          "░╚════╝░░╚════╝░╚═════╝░░░░╚═╝░░░  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═════╝░  ╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚══════╝"
        ];
        highlight = "Statement";
      };
      body = section // {
        type = "mapping";
        title = "Menu";
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
      };
      options.paddings = [
        1
        3
      ];
      parts = [
        "header"
        "body"
      ];
    };
  };
}
