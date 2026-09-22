{
  pkgs,
  ...
}:

{
  hardware.openrazer = {
    enable = true;
    users = [ "codyt" ];
    devicesOffOnScreensaver = false;
  };

  environment.systemPackages = [ pkgs.polychromatic ];
}
