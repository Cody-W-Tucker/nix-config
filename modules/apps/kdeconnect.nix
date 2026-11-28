{
  den.aspects.apps = {
    nixos.networking.firewall =
      let
        kdeConnectPorts = [
          {
            from = 1714;
            to = 1764;
          }
        ];
      in
      {
        allowedTCPPortRanges = kdeConnectPorts;
        allowedUDPPortRanges = kdeConnectPorts;
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
