{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    inputs.flake-programs-sqlite.nixosModules.programs-sqlite
    ../../secrets/secrets.nix
    ../../users/home.nix
  ];
}
