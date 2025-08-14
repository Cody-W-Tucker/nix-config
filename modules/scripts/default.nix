{ pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./media-player.nix
    ./bluetooth-switch.nix
    ./todoist-rofi.nix
    ./update.nix
    ./waybar-tasks.nix
    ./rofi-taskwarrior.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  environment.systemPackages = with pkgs; [
    jq # needed with web-search
    inotify-tools # needed with waybar tasks
    yt-dlp
    # Adding the scripts to the system packages
  ] ++ scriptPackages;
}
