{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.codyos.hardware.openrazer.enable = lib.mkEnableOption "OpenRazer driver and Polychromatic";

  config = lib.mkIf config.codyos.hardware.openrazer.enable {
    hardware.openrazer = {
      enable = true;
      users = [ config.codyos.site.user.name ];
      devicesOffOnScreensaver = false;
    };

    environment.systemPackages = [ pkgs.polychromatic ];
  };
}
