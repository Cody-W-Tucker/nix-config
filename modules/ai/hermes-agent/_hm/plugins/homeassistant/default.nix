{
  config,
  lib,
  pkgs,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
  };
  homeAssistantPlugin = pkgs.runCommand "homeassistant" { } ''
    cp -R ${officialPlugins}/homeassistant "$out"
    # Hermes's Nix derivation reports version 0.0.0 even though this pinned
    # core includes the post-extraction plugin API. Avoid a false version-gate
    # rejection of the official Home Assistant plugin.
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.21.5"' 'requires_hermes: ">=0.0.0"'
  '';
in
{
  home.activation.hermesHomeAssistantPlugin = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    $DRY_RUN_CMD ln -sfn ${homeAssistantPlugin} ${config.services.hermes-agent.hermesHome}/plugins/homeassistant
  '';
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 900 [ homeAssistantPlugin ];
    # HASS_TOKEN comes from the existing Hermes SOPS secret.
    environment.HASS_URL = "http://127.0.0.1:8123";
  };
}
