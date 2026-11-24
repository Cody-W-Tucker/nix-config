{ config, ... }:

{
  config = {
    # `hermes` is a single multiline secret whose plaintext is plain
    # KEY=value lines carrying the agent's env var names directly
    # (TELEGRAM_BOT_TOKEN, API_SERVER_KEY, HASS_TOKEN, ...). Templates
    # render it verbatim, so there is no rename step.
    sops.secrets."hermes" = { };
    sops.secrets."opencode-api-key" = { };
    sops.secrets."karakeep-api-key" = { };

    # Mealie API token. Rendered into hermes-env as MEALIE_API_KEY so the
    # agent can call https://mealie.homehub.tv OpenAPI directly.
    sops.secrets."mealie-api-key" = { };

    # OpenCode web basic-auth. Same sops key as modules/ai/opencode
    # (opencode-env). Hermes CLI attach reads OPENCODE_SERVER_PASSWORD.
    sops.secrets."opencode-password" = { };

    # Home Assistant long-lived access token. Rendered into hermes-env as
    # HASS_TOKEN so the agent can call http://127.0.0.1:8123 directly.
    sops.secrets."hass-token" = { };

    # Dashboard credentials live in their own secret so they never land
    # in the agent process environment (and vice versa).
    sops.secrets."hermes-dashboard" = { };

    # Root-owned: upstream's activation (ordered after setupSecrets) merges
    # environmentFiles into HERMES_HOME/.env, and systemd reads the dashboard
    # file. A changed secret takes effect on the next restart.
    sops.templates."hermes-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
        KARAKEEP_API_KEY=${config.sops.placeholder."karakeep-api-key"}
        MEALIE_API_KEY=${config.sops.placeholder."mealie-api-key"}
        HASS_TOKEN=${config.sops.placeholder."hass-token"}
      '';
      restartUnits = [ "hermes-agent.service" ];
    };

    sops.templates."hermes-agent-env" = {
      content = config.sops.placeholder."hermes";
      restartUnits = [ "hermes-agent.service" ];
    };

    sops.templates."hermes-dashboard-env" = {
      content = config.sops.placeholder."hermes-dashboard";
      restartUnits = [ "hermes-backend.service" ];
    };

    # The NixOS module writes environmentFiles into .env only; the dashboard
    # reads its basic auth from the unit environment.
    systemd.services.hermes-backend.serviceConfig.EnvironmentFile = [
      config.sops.templates."hermes-dashboard-env".path
    ];
  };
}
