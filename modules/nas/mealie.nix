{
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:

{
  # WORKAROUND (2026-08-23): Mealie 2.8.x downloads NLTK corpora to /nltk_data at
  # import time; as a systemd service that directory is not writable, so the unit
  # fails to start.
  # Upstream issue: https://github.com/mealie-recipes/mealie/issues/5242
  # Upstream fix: https://github.com/mealie-recipes/mealie/pull/5290
  # REVIEW-BY: 2026-11-23 — drop `package` once stable/unstable mealie bundles the
  # NLTK data (no import-time /nltk_data write). No reliable consumer-scoped
  # predicate is observable from this config, so the deadline comment drives review.
  services.mealie = {
    enable = true;
    package = inputs.nixpkgs-prior.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mealie;
    port = 9000;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "mealie.homehub.tv";
    port = 9000;
  };
}
