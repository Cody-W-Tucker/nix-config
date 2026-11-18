{
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-secrets.nixosModules.default
    ./scripts.nix
    ./locale.nix
    ./nix.nix
    ./overlays.nix
    ./users.nix
    ./packages.nix
    ./shell.nix
    ./services.nix
    ./networking.nix
    ./logging.nix
    ./site.nix

    # Opt-in feature option modules: always imported, inert until a host or profile
    # sets the matching codyos.*.enable option.
    ../hardware/nvidia.nix
    ../desktop/gaming
    ../desktop/hardware/openrazer
  ];

  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
