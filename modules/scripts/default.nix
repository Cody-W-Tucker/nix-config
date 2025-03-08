{ pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./media-player.nix
    ./bluetooth-switch.nix
    ./web-scraper.nix
    ./waybar-timer.nix
    ./obsidian-writer.nix
    ./get-weather.nix
    ./keybind-logger.nix
    ./todoist-rofi.nix
    ./update.nix
    ./file-contents-search.nix
    ./waybar-tasks.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  environment.systemPackages = with pkgs; [
    jq # needed with web-search
    inotify-tools # needed with waybar tasks
    # Adding the scripts to the system packages
  ] ++ scriptPackages;

}
