{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    inputs.flake-programs-sqlite.nixosModules.programs-sqlite
    ./locale.nix
    ./nix.nix
    ./users.nix
    ./fonts.nix
    ./packages.nix
    ./shell.nix
    ./services.nix
    ./networking.nix
    ../../secrets/secrets.nix
    ../../users/home.nix
  ];
}
