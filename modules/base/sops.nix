{ inputs, ... }:
{
  # sops-nix and nixos-secrets option modules, imported on every host so any aspect can
  # declare sops.secrets / sops.templates.
  den.aspects.sops.nixos.imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-secrets.nixosModules.default
  ];
}
