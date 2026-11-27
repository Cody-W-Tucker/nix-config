{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.gaming ];

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
        prismlauncher
      ];
      powerManagement.cpuFreqGovernor = "performance";
    };
}
