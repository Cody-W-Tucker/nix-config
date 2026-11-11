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
    ./scripts.nix
    ./locale.nix
    ./nix.nix
    ./overlays.nix
    ./users.nix
    ./fonts.nix
    ./packages.nix
    ./shell.nix
    ./services.nix
    ./networking.nix
    ./site.nix
    ../../users/home.nix

    # Opt-in features: always imported, inert until a host or profile sets
    # the matching codyos.*.enable option.
    ../hardware/nvidia.nix
    ../desktop/gaming
    ../desktop/hardware/openrazer
    ../services/docker.nix
    ../services/hindsight
    ../services/nginx # provides mkNginxVhost to feature modules
    ../services/open-ontologies
    ../services/opencode
    ../services/paperless-scanning
  ];

  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
