{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./nixvim.nix
    ./appLauncher.nix
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # Add some packages to the user environment.
    grim
    slurp
    wl-clipboard
    hyprpicker
    rofi-wayland
    vscode
    gh
    ripdrag
    spotify
    blueman
    playerctl
  ];

  # Clipboard history
  services.cliphist.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;

  # Start spotify on login
  systemd.user.services.spotify = {
    Unit = {
      Description = "Spotify";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.spotify}/bin/spotify --no-zygote --minimized";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
