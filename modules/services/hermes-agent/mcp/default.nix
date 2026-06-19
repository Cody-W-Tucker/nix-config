{
  config,
  pkgs,
  ...
}:

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
in
{
  config = {
    sops.secrets = {
      "karakeep-api-key" = {
        owner = config.services.hermes-agent.user;
        inherit (config.services.hermes-agent) group;
        mode = "0440";
      };
    };
    services.hermes-agent = {
      mcpServers.karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
    };
  };
}
