{ inputs, ... }:
{
  flake.overlays.default = import ./_overlay.nix { inherit inputs; };
}
