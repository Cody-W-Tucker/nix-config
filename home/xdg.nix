{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
