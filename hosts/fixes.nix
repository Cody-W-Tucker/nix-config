{
  # Temporary insecure-package exceptions — remove when upstream issues are resolved.
  nixpkgs.config.permittedInsecurePackages = [
    # Hermes container module hardcodes pkgs.docker (docker_28) for the CLI path.
    "docker-28.5.2"
    # Karakeep pins pnpm-9.15.9: https://github.com/NixOS/nixpkgs/issues/539235
    "pnpm-9.15.9"
  ];
}
