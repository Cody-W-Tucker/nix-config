{
  inputs,
  home-manager-input,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    home-manager-input.nixosModules.home-manager
    ../../packages/system-scripts
    ./locale.nix
    ./nix.nix
    ./users.nix
    ./fonts.nix
    ./packages.nix
    ./shell.nix
    ./services.nix
    ./networking.nix
    inputs.nixos-secrets.nixosModules.default
    ../../users/home.nix
  ];
}
