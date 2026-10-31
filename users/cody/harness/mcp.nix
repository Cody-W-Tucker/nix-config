{ ... }:
{
  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      open-ontologies = {
        url = "http://100.81.249.65:18082/mcp";
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
