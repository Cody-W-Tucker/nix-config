{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Hermes container module writes the selected docker derivation into the
  # hermes-agent systemd unit's preStart. Today it hardcodes docker_28 even
  # when top-level pkgs.docker has moved past 28.x, so we detect the insecure
  # selection by inspecting the generated command for the docker-28 derivation
  # name (e.g. /nix/store/...-docker-28.5.2/bin/docker) rather than consulting
  # pkgs.docker.version, which reflects the top-level package, not Hermes.
  hermesStillUsesDocker28 =
    config.services.hermes-agent.enable
    && config.services.hermes-agent.container.enable
    && config.services.hermes-agent.container.backend == "docker"
    && lib.hasInfix "-docker-28." config.systemd.services.hermes-agent.preStart;

  # Karakeep pins pnpm-9.15.9 in its nativeBuildInputs.
  # https://github.com/NixOS/nixpkgs/issues/539235
  karakeepStillUsesPnpm9159 =
    config.services.karakeep.enable
    && builtins.any (dep: (dep.name or "") == "pnpm-9.15.9")
      (config.services.karakeep.package.nativeBuildInputs or []);
in
{
  # Temporary insecure-package exceptions.
  # REVIEW-BY: 2026-09-30 — remove entries (and their predicates) once upstream resolves them.
  nixpkgs.config.permittedInsecurePackages = [
    # REVIEW-BY: 2026-09-30 — hermes-agent container backend hardcodes pkgs.docker.
    "docker-28.5.2"
    # REVIEW-BY: 2026-09-30 — karakeep pins pnpm-9.15.9 (see issue below).
    "pnpm-9.15.9"
  ];

  warnings =
    # Warn when the consumer is enabled but no longer actually selects the insecure dep,
    # meaning the corresponding permittedInsecurePackages entry is obsolete.
    (lib.optional
      (config.services.hermes-agent.enable && !hermesStillUsesDocker28)
      "Hermes no longer selects docker-28: remove 'docker-28.5.2' from permittedInsecurePackages (and the hermesStillUsesDocker28 predicate in hosts/fixes.nix)."
    )
    ++ (lib.optional
      (config.services.karakeep.enable && !karakeepStillUsesPnpm9159)
      "Karakeep no longer uses pnpm-9.15.9 (https://github.com/NixOS/nixpkgs/issues/539235): remove 'pnpm-9.15.9' from permittedInsecurePackages (and the karakeepStillUsesPnpm9159 predicate in hosts/fixes.nix)."
    );
}
