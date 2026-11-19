{
  # Steam, gamescope, gamemode and gaming performance tweaks. Including the aspect turns it on.
  den.aspects.gaming.nixos =
    { pkgs, ... }:
    {
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
