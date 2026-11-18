{ inputs, ... }:
{
  # NixVim editor for the user, with the nixvim Home Manager module that pairs with the
  # host's Home Manager: unstable nixvim on unstable hosts (beast), nixvim-stable on stable
  # ones (nas). `host.channel` comes from the host definition (modules/hosts/<host>.nix).
  # The desktop-only plugin set is den.aspects.nixvim-desktop (desktop.nix).
  den.aspects.nixvim.homeManager =
    { host, ... }:
    {
      imports = [
        (if host.channel == "unstable" then inputs.nixvim else inputs.nixvim-stable).homeModules.nixvim
        ./_nixvim.nix
      ];
    };
}
