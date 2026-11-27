{ inputs, ... }:
{
  flake.formatter.x86_64-linux = (import ./_pkgs.nix { inherit inputs; }).nixfmt-tree;
}
