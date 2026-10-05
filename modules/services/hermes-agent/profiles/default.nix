{ ... }:
{
  # Composition only: profile catalog plus config, activation, and validation siblings.
  imports = [
    ./catalog.nix
    ./config.nix
    ./activation.nix
    ./validation.nix
  ];
}
