{
  inputs,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-secrets.nixosModules.default
    ./_scripts.nix
    ./_locale.nix
    ./_nix.nix
    ./_overlays.nix
    ./_users.nix
    ./_packages.nix
    ./_shell.nix
    ./_services.nix
    ./_networking.nix
    ./_logging.nix
    ./_site.nix

    # Opt-in feature option modules: always imported, inert until a host or profile
    # sets the matching codyos.*.enable option.
    ../hardware/_nvidia.nix
    ../_legacy/desktop/gaming
    ../_legacy/desktop/hardware/openrazer
  ];

  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
