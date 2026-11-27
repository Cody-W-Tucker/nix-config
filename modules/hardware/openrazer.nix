{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.openrazer ];

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

    provides.to-users.homeManager.xdg.configFile."autostart/polychromatic-autostart.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
