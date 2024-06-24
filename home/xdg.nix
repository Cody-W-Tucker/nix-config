{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  shared = "/mnt/share";
in
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      documents = "/mnt/share/Documents";
      music = "/mnt/share/Music";
      pictures = "/mnt/share/Pictures";
      videos = "/mnt/share/Videos";
    };
  };
}
