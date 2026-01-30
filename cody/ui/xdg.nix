{ pkgs, config, ... }:
let
  inherit (pkgs) writeText;
  inherit (config) xdg;
in
{
  # Enable XDG user directories with custom Projects folder
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    extraConfig = {
      XDG_PROJECTS_DIR = "$HOME/Projects";
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
      prefix=${xdg.cacheHome}/npm
      cache=${xdg.cacheHome}/npm
      tmp=$XDG_RUNTIME_DIR/npm
      init-module=${xdg.configHome}/npm/config/npm-init.js
    '';
  };
  # Default applications
  xdg.mime.enable = true;
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

      # Text: HTML, CSS, JS, Markdown, JSON, plain text
      "text/*" = "nvim.desktop";
      "application/json" = "nvim.desktop"; # JSON is technically not text/*
      "application/javascript" = "nvim.desktop"; # For explicit JS files

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
