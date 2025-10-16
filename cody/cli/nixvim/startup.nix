{ ... }:

{
  programs.nixvim.startup = {
    enable = true;
    parts = [
      "body"
      "header"
    ];
    sections = {
      body = {
        align = "center";
        content = [
          [
            " Find File"
            "Telescope find_files"
            "<leader>ff"
          ]
          [
            "󰍉 Find Word"
            "Telescope live_grep"
            "<leader>lg"
          ]
          [
            " Recent Files"
            "Telescope oldfiles"
            "<leader>of"
          ]
          [
            " File Browser"
            "Telescope file_browser"
            "<leader>fb"
          ]
          [
            " Colorschemes"
            "Telescope colorscheme"
            "<leader>cs"
          ]
          [
            " New File"
            "lua require'startup'.new_file()"
            "<leader>nf"
          ]
        ];
        defaultColor = "";
        foldSection = true;
        highlight = "String";
        margin = 5;
        oldfilesAmount = 0;
        title = "Basic Commands";
        type = "mapping";
      };
      header = {
        align = "center";
        content = {
          __raw = "require('startup.headers').hydra_header";
        };
        defaultColor = "";
        foldSection = false;
        highlight = "Statement";
        margin = 5;
        oldfilesAmount = 0;
        title = "Header";
        type = "text";
      };
    };
  };
}
