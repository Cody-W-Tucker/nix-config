{ config, ... }:

{
  config = {
    sops = {
      secrets = {
        "hermes" = { };
        "opencode-api-key" = { };
        "karakeep-api-key" = { };
        "mealie-api-key" = { };
        "opencode-password" = { };
        "hass-token" = { };
        "hermes-dashboard" = { };
      };

      templates = {
        "hermes-env" = {
          content = ''
            OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
            OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
            KARAKEEP_API_KEY=${config.sops.placeholder."karakeep-api-key"}
            MEALIE_API_KEY=${config.sops.placeholder."mealie-api-key"}
            HASS_TOKEN=${config.sops.placeholder."hass-token"}
          '';
          restartUnits = [ "hermes-agent.service" ];
        };

        "hermes-agent-env" = {
          content = config.sops.placeholder."hermes";
          restartUnits = [ "hermes-agent.service" ];
        };

        "hermes-dashboard-env" = {
          content = config.sops.placeholder."hermes-dashboard";
          restartUnits = [ "hermes-backend.service" ];
        };
      };
    };

    systemd.services.hermes-backend.serviceConfig.EnvironmentFile = [
      config.sops.templates."hermes-dashboard-env".path
    ];
  };
}
