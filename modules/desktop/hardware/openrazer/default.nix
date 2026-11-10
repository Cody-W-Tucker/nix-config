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
      users = [ "codyt" ];
      devicesOffOnScreensaver = false;
    };

    environment.systemPackages = [ pkgs.polychromatic ];
  };
}
