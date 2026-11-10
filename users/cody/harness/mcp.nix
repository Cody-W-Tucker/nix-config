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
      deja = {
        command = lib.getExe dejaMcp;
        args = [ "mcp" ];
      };
      open-ontologies = {
        url =
          if osConfig.networking.hostName == "nas" then
            "http://127.0.0.1:18081/mcp"
          else
            "http://100.81.249.65:18082/mcp";
      };
      exa = {
        type = "remote";
        url = "https://mcp.exa.ai/mcp";
      };
      context7 = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @upstash/context7-mcp"
        ];
      };
      gh_grep = {
        type = "remote";
        url = "https://mcp.grep.app";
      };
      nixos-option-search = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };
    };
  };
}
