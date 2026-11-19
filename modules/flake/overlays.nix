# Shared overlay; adds local packages and pkgs.unstable (see ./_overlay.nix).
{ inputs, ... }:
{
  flake.overlays.default = import ./_overlay.nix { inherit inputs; };
}
