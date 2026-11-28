{
  den.aspects.harness.homeManager =
    {
      host,
      inputs,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
      embedding = {
        DEJA_EMBED_URL = "http://${
          if host.localAi then "127.0.0.1" else osConfig.codyos.site.hosts.nas.tailscale
        }:8081/v1/embeddings";
        DEJA_EMBED_MODEL = "qwen3-embedding-0.6b";
        DEJA_EMBED_QUERY_PREFIX = "Instruct: Given a search query, retrieve relevant passages that answer the query\nQuery: ";
      };
      dejaMcp = pkgs.writeShellApplication {
        name = "deja-mcp";
        runtimeInputs = [ pkgs.sqlite ];
        text = ''
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") embedding
          )}
          exec ${lib.getExe deja} mcp
        '';
      };
    in
    {
      home = {
        sessionVariables = embedding;
        packages = [
          deja
          pkgs.sqlite
        ];
      };

      xdg.configFile."deja/exclude".text = ''
        harness:pi
      '';

      codyos.harness.skills.deja-search = "${deja.src}/skills/deja-search";

      programs.mcp.servers.deja.command = lib.getExe dejaMcp;

      programs.opencode.settings.plugins = [
        {
          package = "${deja.src}/extensions/opencode";
          options = {
            autoRecall = false;
            tools = false;
          };
        }
      ];
    };
}
