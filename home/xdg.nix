{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      documents = "${home}/Documents";
      music = "${home}/Music";
      pictures = "${home}/Pictures";
      videos = "${home}/Videos";
    };
  };
}
