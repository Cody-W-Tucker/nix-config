{
  # XDG user directories, document-viewer desktop entries and default applications.
  den.aspects.graphical = {
    provides.to-users.homeManager =
      { pkgs, ... }:
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
            mimeType = [
              "application/msword"
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
              "application/vnd.ms-word.document.macroEnabled.12"
              "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
              "application/vnd.ms-word.template.macroEnabled.12"
            ];
          };
          desktopEntries.xleak = {
            name = "xleak";
            genericName = "Excel Spreadsheet Viewer";
            exec = "${pkgs.kitty}/bin/kitty -e ${pkgs.xleak}/bin/xleak -i --wrap -H %f";
            mimeType = [
              "application/vnd.ms-excel"
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              "application/vnd.ms-excel.sheet.macroEnabled.12"
              "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
              "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
              "application/vnd.ms-excel.template.macroEnabled.12"
            ];
          };
          configFile."xleak/config.toml".text = ''
            [keybindings]
            profile = "vim"

            [theme]
            default = "Dracula"
          '';
          mimeApps = {
            enable = true;
            defaultApplications = {
              "image/*" = "feh.desktop";
              "video/*" = "mpv.desktop";
              "audio/*" = "mpv.desktop";
              "application/pdf" = "org.pwmt.zathura.desktop";
              "application/msword" = "doxx.desktop";
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "doxx.desktop";
              "application/vnd.ms-word.document.macroEnabled.12" = "doxx.desktop";
              "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = "doxx.desktop";
              "application/vnd.ms-word.template.macroEnabled.12" = "doxx.desktop";
              "application/vnd.ms-excel" = "xleak.desktop";
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "xleak.desktop";
              "application/vnd.ms-excel.sheet.macroEnabled.12" = "xleak.desktop";
              "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = "xleak.desktop";
              "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = "xleak.desktop";
              "application/vnd.ms-excel.template.macroEnabled.12" = "xleak.desktop";
              "text/*" = "nvim.desktop";
              "text/html" = "zen-beta.desktop";
              "application/json" = "nvim.desktop"; # JSON is technically not text/*
              "application/javascript" = "nvim.desktop"; # For explicit JS files
              "application/x-subrip" = "nvim.desktop"; # For .srt subtitle files
              "x-scheme-handler/http" = "zen-beta.desktop";
              "x-scheme-handler/https" = "zen-beta.desktop";
            };
          };
        };
        home.packages = with pkgs; [
          feh # Image viewer
          zathura # PDF viewer
          mpv # Media player
          xleak # Excel spreadsheet viewer
          doxx # Word document viewer
        ];
      };
  };
}
