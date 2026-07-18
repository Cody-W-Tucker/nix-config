{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = {
    services.hermes-agent = {
      mcpServers.karakeep = {
        command = lib.getExe' pkgs.nodejs "npx";
        args = [
          "-y"
          "@karakeep/mcp"
        ];
        env.KARAKEEP_API_ADDR = "http://127.0.0.1:3005";
        env.KARAKEEP_API_KEY = "\${KARAKEEP_API_KEY}";
      };
    };
  };
}
