{ pkgs, config, ... }:
let
  inherit (pkgs) writeText;
  inherit (config) xdg;
in
{
  # Enable XDG user directories with custom folders
  xdg.userDirs = {
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

  # Override the default XDG directories for items that don't follow the XDG spec
  home.sessionVariables = {
    PYLINTHOME = "${xdg.cacheHome}/pylint";
    XCOMPOSECACHE = "${xdg.cacheHome}/X11/xcompose";
    XCOMPOSEFILE = "${xdg.configHome}/X11/xcompose";
    IPYTHONDIR = "${xdg.dataHome}/ipython";
    JUPYTER_CONFIG_DIR = "${xdg.dataHome}/ipython";
    HISTFILE = "${xdg.dataHome}/histfile";

    NPM_CONFIG_USERCONFIG = writeText "npmrc" ''
      prefix=${xdg.dataHome}/npm
      cache=${xdg.cacheHome}/npm
      init-module=${xdg.configHome}/npm/config/npm-init.js
    '';
  };
  # Default applications
  xdg.mime.enable = true;
  xdg.desktopEntries.doxx = {
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
  xdg.mimeApps = {
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
  # Install the Applications
  home.packages = with pkgs; [
    # list of stable packages go here
    feh # Image viewer
    zathura # PDF viewer
    mpv # Media player
  ];
}
