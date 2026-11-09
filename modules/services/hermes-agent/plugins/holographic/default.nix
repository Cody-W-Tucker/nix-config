{
  config,
  lib,
  pkgs,
  ...
}:
let
  holographicPlugin = pkgs.fetchFromGitHub {
    owner = "itpartypattaya";
    repo = "hermes-plugin-holographic";
    name = "holographic";
    rev = "a6d009315bc72a7c4e68d6a0e60a6eeed68080fd";
    hash = "sha256-JkHG1Rmb+5H3d/jpMrpQ1x8H8b1kgc+QorV4uQXCKaM=";
  };
in
{
  home.activation.hermesHolographicPlugin = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    $DRY_RUN_CMD ln -sfn ${holographicPlugin} ${config.services.hermes-agent.hermesHome}/plugins/holographic
  '';
  services.hermes-agent.settings.plugins = {
    "hermes-memory-store".auto_extract = false;
  };
}
