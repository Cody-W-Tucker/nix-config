{ den, inputs, ... }:
{
  den.aspects.secrets.nixos.imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-secrets.nixosModules.default
  ];

  den.default.includes = [ den.aspects.secrets ];
}
