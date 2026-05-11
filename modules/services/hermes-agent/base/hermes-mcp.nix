{ pkgs, config, ... }:
let
  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.homehub.tv"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY

      exec npx -y @karakeep/mcp "$@"
    '';
  };

  exaMcp = pkgs.writeShellApplication {
    name = "exa-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      EXA_API_KEY="$(< ${config.sops.secrets.exa-api-key.path})"
      export EXA_API_KEY

      exec npx -y exa-mcp-server "$@"
    '';
  };
in

{
  config = {
    sops = {
      secrets = {
        "karakeep-api-key" = {
          owner = config.services.hermes-agent.user;
          inherit (config.services.hermes-agent) group;
        };
        "exa-api-key" = {
          owner = config.services.hermes-agent.user;
          inherit (config.services.hermes-agent) group;
        };
      };
    };

    services.hermes-agent = {
      mcpServers.karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
      mcpServers.exa.command = "${exaMcp}/bin/exa-mcp";
    };
  };
}
