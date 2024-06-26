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
      documents = "/mnt/share/Documents";
      music = "/mnt/share/Music";
      pictures = "/mnt/share/Pictures";
      videos = "/mnt/share/Videos";
      extraConfig = {
        Business = "/mnt/share/Business";
        Projects = "/mnt/share/Projects";
        Records = "/mnt/share/Records";
        Tools = "/mnt/share/Tools";
      };
    };
  };
}
