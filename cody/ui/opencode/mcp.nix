{ ... }:

{
  programs.mcp = {
    enable = true;
    servers = {
      docs-langchain = {
        url = "https://docs.langchain.com/mcp";
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
