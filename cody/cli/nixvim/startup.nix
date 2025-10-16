{ ... }:

{
  programs.nixvim.plugins.startup = {
    enable = true;
    sections = {
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
            " Find File"
            "Telescope find_files"
            "ff"
          ]
          [
            "󰍉 Find Word"
            "Telescope live_grep"
            "fg"
          ]
          [
            " Recent Files"
            "Telescope oldfiles"
            "fo"
          ]
          [
            " File Browser"
            "Telescope file_browser"
            "-"
          ]
        ];
        highlight = "string";
        defaultColor = "";
        oldfilesAmount = 0;
      };
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
}
