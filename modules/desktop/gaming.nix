{ pkgs, ... }:

{
  # Enable OpenGL for 32-bit applications (steam, games, etc.)
  hardware.graphics.enable32Bit = true;

  # Gaming Configuration
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  # Gaming specific packages
  environment.systemPackages = (
    with pkgs;
    [
      # list of stable packages go here
      gamescope-wsi
    ]
  );

  # Performance Tweaks
  powerManagement.cpuFreqGovernor = "performance";
}
