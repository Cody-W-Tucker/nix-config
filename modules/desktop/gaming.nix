{ pkgs, ... }:

{
  # Gaming Configuration
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  # Gaming specific packages
  environment.systemPackages =
    (with pkgs; [
      # list of stable packages go here
      gamescope-wsi
    ]);
}
