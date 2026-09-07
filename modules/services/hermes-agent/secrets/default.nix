{
  config,
  lib,
  ...
}:

let
  inherit (config.services.hermes-agent) stateDir;

  agentEnvFile = "${stateDir}/hermes.env";
  dashboardEnvFile = "${stateDir}/hermes-dashboard.env";

in
{
  config = {
    # `hermes` is a single multiline secret whose plaintext is plain
    # KEY=value lines carrying the agent's env var names directly
    # (TELEGRAM_BOT_TOKEN, API_SERVER_KEY, ...). Templates render it
    # verbatim, so there is no rename step. Waybar hosts decrypt the
    # same `hermes` key via home-manager; its voice widget extracts
    # API_SERVER_KEY from that copy (users/cody/desktop/waybar.nix).
    sops.secrets."hermes" = { };
    sops.secrets."opencode-api-key" = { };

    # Dashboard credentials live in their own secret so they never land
    # in the agent process environment (and vice versa).
    sops.secrets."hermes-dashboard" = { };

    # Secrets that are still one value each keep the template mechanism.
    sops.templates."hermes-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        KARAKEEP_API_KEY=${config.sops.placeholder."karakeep-api-key"}
      '';
    };

    # sops-nix renders these during setupSecrets; upstream's
    # hermes-agent-setup is already ordered after setupSecrets and merges
    # environmentFiles into ${stateDir}/.hermes/.env, so the files exist
    # by then. Values never enter the Nix store. Root-owned 0600, as the
    # files were under the old activation renderer. restartUnits
    # propagates rotation; the assertion below catches dangling unit
    # names at eval instead of at switch time.
    sops.templates."hermes-agent-env" = {
      content = config.sops.placeholder."hermes";
      path = agentEnvFile;
      mode = "0600";
      restartUnits = [ "hermes-agent.service" ];
    };

    sops.templates."hermes-dashboard-env" = {
      content = config.sops.placeholder."hermes-dashboard";
      path = dashboardEnvFile;
      mode = "0600";
      restartUnits = [ "hermes-dashboard.service" ];
    };

    assertions =
      map
        (unit: {
          assertion = config.systemd.services ? ${lib.removeSuffix ".service" unit};
          message = "modules/services/hermes-agent/secrets: restartUnits references ${unit}, but no such systemd service is defined on this host.";
        })
        [
          "hermes-agent.service"
          "hermes-dashboard.service"
        ];
  };
}
