{
  # Desktop-only nixvim additions (web/Python/Zig language servers, formatters, the
  # wl-copy clipboard provider). Included by beast only; nas keeps the base editor.
  den.aspects.nixvim-desktop.provides.to-users.homeManager.imports = [ ./_plugins/desktop.nix ];
}
