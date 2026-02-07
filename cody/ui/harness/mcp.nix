{ ... }:

{
  programs.mcp.servers = {
    enable = true;
    docs-langchain = {
      url = "https://docs.langchain.com/mcp";
    };
    nixos-option-search = {
      command = [ "nix" ];
      args = [
        "run"
        "github:utensils/mcp-nixos"
      ];
    };
  };
}
