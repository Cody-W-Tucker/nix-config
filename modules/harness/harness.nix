{ den, ... }:
{
  den.aspects = {
    beast.includes = [ den.aspects.harness.browse ];

    harness = {
      homeManager =
        { host, ... }:
        {
          imports = [ (import ./_hm { inherit (host) localAi; }) ];
        };

      browse.provides.to-users.homeManager =
        {
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          browse = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode-browse;
        in
        {
          home.packages = [ browse ];
          programs.opencode.settings.mcp.servers.browse = {
            type = "local";
            command = [
              (lib.getExe browse)
              "mcp"
            ];
          };
        };
    };
  };

  den.default.includes = [ den.aspects.harness ];
}
