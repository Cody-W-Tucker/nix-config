{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.nixvim.desktop ];

  den.aspects.nixvim.homeManager =
    { host, ... }:
    {
      imports = [
        host.nixvimModule
        ./_nixvim.nix
      ];
    };

  den.aspects.nixvim.desktop.provides.to-users.homeManager.imports = [ ./_plugins/desktop.nix ];

  den.default.includes = [ den.aspects.nixvim ];
}
