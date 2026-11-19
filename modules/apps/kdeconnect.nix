{
  # KDE Connect: phone integration (user daemon + indicator) and its discovery ports.
  den.aspects.apps = {
    nixos.networking.firewall = {
      # Open firewall ports for KDE Connect discovery
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
        # Connect phone to computer
        enable = true;
        indicator = true;
      };
    };
  };
}
