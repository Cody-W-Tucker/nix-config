{ inputs, ... }:
let
  # Keep the exact nixosSystem call shape the flake used before Den.
  mkInstantiate =
    nixosSystem: args:
    nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
      }
    );
in
{
  # beast tracks nixpkgs-unstable; nas tracks stable nixpkgs.
  den.hosts.x86_64-linux.beast.instantiate = mkInstantiate inputs.nixpkgs-unstable.lib.nixosSystem;
  den.hosts.x86_64-linux.nas.instantiate = mkInstantiate inputs.nixpkgs.lib.nixosSystem;
}
