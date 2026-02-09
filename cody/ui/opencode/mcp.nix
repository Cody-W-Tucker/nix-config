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
      memory = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @modelcontextprotocol/server-memory"
        ];
        env = {
          MEMORY_FILE_PATH = "~/.config/mcp/memory.json";
        };
      };
    };
  };
}
