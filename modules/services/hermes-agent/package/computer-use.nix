{
  lib,
  pkgs,
  hermesCuaDriver,
  ...
}:

let
  driverPath = lib.getExe hermesCuaDriver;
in
{
  _module.args.hermesComputerUsePackageEnv = ''
    export HERMES_CUA_DRIVER_CMD=${pkgs.lib.escapeShellArg driverPath}
    export CUA_DRIVER_RS_ENABLE_WAYLAND=1
  '';
}
