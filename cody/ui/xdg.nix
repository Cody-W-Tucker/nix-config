{ pkgs, config, lib, ... }:
let
  inherit (pkgs) writeText;
  inherit (config) xdg;
in
{
  home.sessionVariables = {
    LESSKEY = "${xdg.cacheHome}/less/key";
    LESSHISTFILE = "${xdg.cacheHome}/less/history";
    PYLINTHOME = "${xdg.cacheHome}/pylint";
    XCOMPOSECACHE = "${xdg.cacheHome}/X11/xcompose";
    XCOMPOSEFILE = "${xdg.configHome}/X11/xcompose";
    MAILCAPS = "${xdg.configHome}/mailcap";
    IPYTHONDIR = "${xdg.dataHome}/ipython";
    JUPYTER_CONFIG_DIR = "${xdg.dataHome}/ipython";
    HISTFILE = "${xdg.dataHome}/histfile";

    NPM_CONFIG_USERCONFIG = writeText "npmrc" ''
      prefix=${xdg.cacheHome}/npm
      cache=${xdg.cacheHome}/npm
      tmp=$XDG_RUNTIME_DIR/npm
      init-module=${xdg.configHome}/npm/config/npm-init.js
    '';

    PYTHONSTARTUP = "${config._dotfiles}/bin/history.py";
  };
}
