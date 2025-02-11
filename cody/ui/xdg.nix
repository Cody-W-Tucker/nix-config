{ pkgs, config, lib, ... }:
let
  inherit (pkgs) writeText;
  inherit (config) xdg;
in
{
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
}
