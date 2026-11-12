{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.codyos.gaming.enable = lib.mkEnableOption "Steam, gamescope, gamemode, and gaming performance tweaks";

  config = lib.mkIf config.codyos.gaming.enable {
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
  };
}
