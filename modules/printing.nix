{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.printing ];

  den.aspects.printing = {
    nixos =
      { pkgs, ... }:
      {
        services = {
          avahi = {
            enable = true;
            nssmdns4 = true;
            openFirewall = true;
          };
          printing = {
            enable = true;
            drivers = [ pkgs.canon-cups-ufr2 ];
          };
        };
      };
  };
}
