{
  den.aspects.graphical = {
    provides.to-users.homeManager =
      { lib, pkgs, ... }:
      let
        docMimeTypes = [
          "application/msword"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          "application/vnd.ms-word.document.macroEnabled.12"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
          "application/vnd.ms-word.template.macroEnabled.12"
        ];
        sheetMimeTypes = [
          "application/vnd.ms-excel"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          "application/vnd.ms-excel.sheet.macroEnabled.12"
          "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
          "application/vnd.ms-excel.template.macroEnabled.12"
        ];
      in
      {
        xdg = {
          userDirs = {
            enable = true;
            createDirectories = true;
            setSessionVariables = false;
            extraConfig = {
              PROJECTS = "$HOME/Projects";
              KNOWLEDGE = "$HOME/Knowledge";
              KNOWLEDGE_PERSONAL = "$HOME/Knowledge/Personal";
              KNOWLEDGE_BASE = "$HOME/Knowledge/Base";
            };
          };
          desktopEntries.doxx = {
            name = "doxx";
            genericName = "Word Document Viewer";
            exec = "${pkgs.kitty}/bin/kitty -e ${pkgs.doxx}/bin/doxx %f";
            mimeType = docMimeTypes;
          };
          desktopEntries.xleak = {
            name = "xleak";
            genericName = "Excel Spreadsheet Viewer";
            exec = "${pkgs.kitty}/bin/kitty -e ${pkgs.xleak}/bin/xleak -i --wrap -H %f";
            mimeType = sheetMimeTypes;
          };
          configFile."xleak/config.toml".text = ''
            [keybindings]
            profile = "vim"

            [theme]
            default = "Dracula"
          '';
          mimeApps = {
            enable = true;
            defaultApplications =
              lib.genAttrs docMimeTypes (_: "doxx.desktop")
              // lib.genAttrs sheetMimeTypes (_: "xleak.desktop")
              // {
                "image/*" = "feh.desktop";
                "video/*" = "mpv.desktop";
                "audio/*" = "mpv.desktop";
                "application/pdf" = "org.pwmt.zathura.desktop";
                "text/*" = "nvim.desktop";
                "text/html" = "zen-beta.desktop";
                "application/json" = "nvim.desktop";
                "application/javascript" = "nvim.desktop";
                "application/x-subrip" = "nvim.desktop";
                "x-scheme-handler/http" = "zen-beta.desktop";
                "x-scheme-handler/https" = "zen-beta.desktop";
              };
          };
        };
        home.packages = with pkgs; [
          feh
          zathura
          mpv
          xleak
          doxx
        ];
      };
  };
}
