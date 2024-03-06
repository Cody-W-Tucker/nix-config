{ config, pkgs, lib, ... }:
let
  home = config.home.homeDirectory;
in
{ 
  xdg = lib.mkForce {
    enable = true;
    dataHome = "${home}/.local/share";
    configHome = "${home}/.config";
    cacheHome = "${home}/.cache";
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${home}/Desktop";
      documents = "${home}/Documents";
      download = "${home}/Downloads";
      music = "${home}/Music";
      pictures = "${home}/Pictures";
      publicShare = "${home}/Public";
      templates = "${home}/Templates";
      videos = "${home}/Videos";
    };
  };
}