{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  crg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code-review-graph;
  deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
  dejaMcp = pkgs.writeShellApplication {
    name = "deja-mcp";
    runtimeInputs = [ pkgs.sqlite ];
    text = "exec ${lib.getExe deja} mcp";
  };
  mcpRegistry = {
    deja.command = lib.getExe dejaMcp;
    karakeep = {
      command = lib.getExe' pkgs.nodejs "npx";
      args = [
        "-y"
        "@karakeep/mcp"
      ];
      env.KARAKEEP_API_ADDR = "http://127.0.0.1:3005";
      env.KARAKEEP_API_KEY = "\${KARAKEEP_API_KEY}";
    };
  };
in
{
  config = {
    # Default profile only: expose selected servers so unrelated MCP schemas
    # and tools never enter its prompt surface.
    services.hermes-agent = {
      extraPackages = [ crg ];
      mcpServers = {
        inherit (mcpRegistry) karakeep deja;
      };
    };
  };
}
