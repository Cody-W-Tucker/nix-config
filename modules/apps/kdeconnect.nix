{
  # KDE Connect: phone integration (user daemon + indicator) and its discovery ports.
  den.aspects.apps = {
    nixos.networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };

    provides.to-users.homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.kdePackages.kpeople ];
      services.kdeconnect = {
        enable = true;
        indicator = true;
      };
    };
  };
}
