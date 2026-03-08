{ pkgs, ... }:

{
  # Enable OpenGL for 32-bit applications (steam, games, etc.)
  hardware.graphics.enable32Bit = true;

  # Gaming Configuration
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };
    gamemode.enable = true;
  };

  # Gaming specific packages
  environment.systemPackages = with pkgs; [
    gamescope-wsi
    prismlauncher # Minecraft launcher with native Linux support
  ];

  # Performance Tweaks
  powerManagement.cpuFreqGovernor = "performance";
}
