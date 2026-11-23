{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.gaming ];

  # Steam, gamescope, gamemode and gaming performance tweaks. Including the aspect turns it on.
  den.aspects.gaming.nixos =
    { pkgs, ... }:
    {
      programs = {
        steam = {
          enable = true;
          gamescopeSession.enable = true;
        };
        gamemode.enable = true;
      };
      environment.systemPackages = with pkgs; [
        gamescope-wsi
        prismlauncher # Minecraft launcher with native Linux support
      ];
      powerManagement.cpuFreqGovernor = "performance";
    };
}
