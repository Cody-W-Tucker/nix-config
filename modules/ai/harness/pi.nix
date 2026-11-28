{
  den.aspects.harness.homeManager =
    { config, lib, ... }:
    let
      pi = config.programs.pi-coding-agent;
    in
    {
      programs.pi-coding-agent = {
        enable = true;
        mutableSettings = true;
      };

      home.file."${pi.configDir}/mcp.json".text = builtins.toJSON {
        mcpServers = lib.mapAttrs (
          _: server: lib.filterAttrs (_: value: value != null && value != [ ] && value != { }) server
        ) config.programs.mcp.servers;
      };
    };
}
