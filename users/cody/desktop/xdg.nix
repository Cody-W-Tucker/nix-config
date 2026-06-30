{ pkgs, ... }:
{
  xdg = {
    userDirs = {
      # Enable XDG user directories with custom folders
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
    mime.enable = true;
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
        # Images: PNG, JPEG, GIF, SVG, WebP
        "image/*" = "feh.desktop";

        # Videos: MP4, WebM
        "video/*" = "mpv.desktop";

        # Audio: MP3, OGG
        "audio/*" = "mpv.desktop";

        # PDFs
        "application/pdf" = "org.pwmt.zathura.desktop";

        # Microsoft Word documents: DOC, DOCX, DOCM, DOTX, DOTM
        "application/msword" = "doxx.desktop";
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "doxx.desktop";
        "application/vnd.ms-word.document.macroEnabled.12" = "doxx.desktop";
        "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = "doxx.desktop";
        "application/vnd.ms-word.template.macroEnabled.12" = "doxx.desktop";

        # Microsoft Excel spreadsheets: XLS, XLSX, XLSM, XLSB, XLTX, XLTM
        "application/vnd.ms-excel" = "xleak.desktop";
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "xleak.desktop";
        "application/vnd.ms-excel.sheet.macroEnabled.12" = "xleak.desktop";
        "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = "xleak.desktop";
        "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = "xleak.desktop";
        "application/vnd.ms-excel.template.macroEnabled.12" = "xleak.desktop";

        # Text: HTML, CSS, JS, Markdown, JSON, plain text
        "text/*" = "nvim.desktop";
        "text/html" = "zen.desktop";
        "application/json" = "nvim.desktop"; # JSON is technically not text/*
        "application/javascript" = "nvim.desktop"; # For explicit JS files
        "application/x-subrip" = "nvim.desktop"; # For .srt subtitle files

        # Web URLs
        "x-scheme-handler/http" = "zen.desktop";
        "x-scheme-handler/https" = "zen.desktop";
      };
    };
  };
  home.packages = with pkgs; [
    # Install the Applications
    # list of stable packages go here
    feh # Image viewer
    zathura # PDF viewer
    mpv # Media player
    xleak # Excel spreadsheet viewer
    doxx # Word document viewer
  ];
}
