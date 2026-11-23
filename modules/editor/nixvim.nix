{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.nixvim.desktop ];

  # NixVim editor for the user, with the nixvim Home Manager module that pairs with the
  # host's Home Manager: unstable nixvim on unstable hosts (beast), nixvim-stable on stable
  # ones (nas). `host.nixvimModule` is derived from the host's `channel`
  # (modules/hosts/channels.nix). Registered on every host via den.default.
  den.aspects.nixvim.homeManager =
    { host, ... }:
    {
      imports = [
        host.nixvimModule
        ./_nixvim.nix
      ];
    };

  # Desktop-only nixvim additions (web/Python/Zig language servers, formatters, the
  # wl-copy clipboard provider). Included by beast only; nas keeps the base editor.
  den.aspects.nixvim.desktop.provides.to-users.homeManager.imports = [ ./_plugins/desktop.nix ];

  den.default.includes = [ den.aspects.nixvim ];
}
