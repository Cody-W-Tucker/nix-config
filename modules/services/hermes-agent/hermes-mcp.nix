{
  pkgs,
  config,
  ...
}:
let
  gbrainMcpUrl = "http://127.0.0.1:3131/mcp";
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
in

{
  config = {
    sops = {
      secrets = {
        "karakeep-api-key" = {
          owner = config.services.hermes-agent.user;
          inherit (config.services.hermes-agent) group;
          mode = "0440";
        };
      };
    };

    services.hermes-agent = {
      mcpServers = {
        gbrain = {
          url = gbrainMcpUrl;
          headers = {
            Accept = "application/json, text/event-stream";
            Authorization = "Bearer \${GBRAIN_MCP_TOKEN}";
          };
        };
        karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
      };
    };
  };
}
