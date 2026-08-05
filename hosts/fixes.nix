{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Karakeep pins pnpm-9.15.9 in its nativeBuildInputs.
  # https://github.com/NixOS/nixpkgs/issues/539235
  karakeepStillUsesPnpm9159 =
    config.services.karakeep.enable
    && builtins.any (dep: (dep.name or "") == "pnpm-9.15.9") (
      config.services.karakeep.package.nativeBuildInputs or [ ]
    );
in
{
  # Temporary insecure-package exceptions.
  # REVIEW-BY: 2026-09-30 — remove entries (and their predicates) once upstream resolves them.
  nixpkgs.config.permittedInsecurePackages = [
    # REVIEW-BY: 2026-09-30 — karakeep pins pnpm-9.15.9 (see issue below).
    "pnpm-9.15.9"
  ];

  warnings =
    # Warn when the consumer is enabled but no longer actually selects the insecure dep,
    # meaning the corresponding permittedInsecurePackages entry is obsolete.
    (
      lib.optional (config.services.karakeep.enable && !karakeepStillUsesPnpm9159)
        "Karakeep no longer uses pnpm-9.15.9 (https://github.com/NixOS/nixpkgs/issues/539235): remove 'pnpm-9.15.9' from permittedInsecurePackages (and the karakeepStillUsesPnpm9159 predicate in hosts/fixes.nix)."
    );
}
