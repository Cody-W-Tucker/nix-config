{
  # OpenRazer driver and Polychromatic. Including the aspect turns it on.
  den.aspects.openrazer = {
    nixos =
      { config, pkgs, ... }:
      {
        hardware.openrazer = {
          enable = true;
          users = [ config.codyos.site.user.name ];
          devicesOffOnScreensaver = false;
        };

        environment.systemPackages = [ pkgs.polychromatic ];
      };

    # Keep the OpenRazer daemon, but don't launch Polychromatic's tray applet.
    provides.to-users.homeManager.xdg.configFile."autostart/polychromatic-autostart.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
