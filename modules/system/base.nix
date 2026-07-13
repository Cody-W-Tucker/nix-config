{
  inputs,
  home-manager-input,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-secrets.nixosModules.default
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
    ../../users/home.nix
  ];
}
