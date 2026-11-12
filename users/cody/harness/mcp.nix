{
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  deja = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu;
  dejaMcp = pkgs.writeShellApplication {
    name = "deja-mcp";
    runtimeInputs = [ pkgs.sqlite ];
    text = "exec ${lib.getExe deja} mcp";
  };
in
{
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
