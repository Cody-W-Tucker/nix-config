{ config, ... }:

{
  config = {
    sops.secrets."hermes" = { };
    sops.secrets."opencode-api-key" = { };
    sops.secrets."karakeep-api-key" = { };

    sops.secrets."mealie-api-key" = { };

    sops.secrets."opencode-password" = { };

    sops.secrets."hass-token" = { };

    sops.secrets."hermes-dashboard" = { };

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

    systemd.services.hermes-backend.serviceConfig.EnvironmentFile = [
      config.sops.templates."hermes-dashboard-env".path
    ];
  };
}
