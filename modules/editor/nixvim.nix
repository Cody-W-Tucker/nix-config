{ den, ... }:
{
  den.aspects = {
    beast.includes = [ den.aspects.nixvim.desktop ];

    nixvim = {
      homeManager =
        { host, ... }:
        {
          imports = [
            host.nixvimModule
            ./_nixvim.nix
          ];
        };

      desktop.provides.to-users.homeManager.imports = [ ./_plugins/desktop.nix ];
    };
  };

  den.default.includes = [ den.aspects.nixvim ];
}
