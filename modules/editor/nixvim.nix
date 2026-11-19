{ den, inputs, ... }:
{
  # NixVim editor for the user, with the nixvim Home Manager module that pairs with the
  # host's Home Manager: unstable nixvim on unstable hosts (beast), nixvim-stable on stable
  # ones (nas). `host.channel` comes from the host definition (modules/hosts/<host>.nix).
  # Registered on every host via den.default.
  den.aspects.nixvim.homeManager =
    { host, ... }:
    {
      imports = [
        (if host.channel == "unstable" then inputs.nixvim else inputs.nixvim-stable).homeModules.nixvim
        ./_nixvim.nix
      ];
    };

  # Desktop-only nixvim additions (web/Python/Zig language servers, formatters, the
  # wl-copy clipboard provider). Included by beast only; nas keeps the base editor.
  den.aspects.nixvim.desktop.provides.to-users.homeManager.imports = [ ./_plugins/desktop.nix ];

  den.default.includes = [ den.aspects.nixvim ];
}
