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

    # Opt-in features: always imported, inert until a host or profile sets
    # the matching codyos.*.enable option.
    ../hardware/nvidia.nix
    ../desktop/gaming
    ../desktop/hardware/openrazer
    ../../services/_docker.nix
    ../../services/_hindsight.nix
    ../../services/_nginx.nix # provides mkNginxVhost to feature modules
    ../../services/_opencode.nix
    ../../services/_paperless-scanning.nix
  ];

  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
