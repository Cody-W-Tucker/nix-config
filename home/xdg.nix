{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  xdg = {
    enable = true;
    dataHome = "${home}/.local/share";
    configHome = "${home}/.config";
    cacheHome = "${home}/.cache";
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
