{
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
  dejaEmbedding = {
    DEJA_EMBED_URL = "http://${
      if osConfig.networking.hostName == "nas" then
        "127.0.0.1"
      else
        osConfig.codyos.site.hosts.nas.tailscale
    }:8081/v1/embeddings";
    DEJA_EMBED_MODEL = "qwen3-embedding-0.6b";
    DEJA_EMBED_QUERY_PREFIX = "Instruct: Given a search query, retrieve relevant passages that answer the query\nQuery: ";
  };
  dejaMcp = pkgs.writeShellApplication {
    name = "deja-mcp";
    runtimeInputs = [ pkgs.sqlite ];
    text = ''
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") dejaEmbedding
      )}
      exec ${lib.getExe deja} mcp
    '';
  };
in
{
  home.sessionVariables = dejaEmbedding;

  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      deja.command = lib.getExe dejaMcp;
      hindsight = {
        type = "remote";
        url =
          if osConfig.networking.hostName == "nas" then
            "http://127.0.0.1:8888/mcp/"
          else
            "http://${osConfig.codyos.site.hosts.nas.tailscale}:18083/mcp/";
      };
      exa = {
        type = "remote";
        url = "https://mcp.exa.ai/mcp";
      };
      context7.command = lib.getExe pkgs.context7-mcp;
      gh_grep = {
        type = "remote";
        url = "https://mcp.grep.app";
      };
      nixos-option-search.command = lib.getExe pkgs.mcp-nixos;
    };
  };
}
