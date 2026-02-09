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
      book-search = {
        command = "nix-shell";
        args = [
          "-p"
          "uv"
          "python3"
          "--run"
          "uvx mcp-server-qdrant --transport stdio"
        ];
        env = {
          QDRANT_URL = "http://localhost:6333";
          COLLECTION_NAME = "ebooks";
          EMBEDDING_MODEL = "nomic-embed-text:latest";
        };
      };
    };
  };
}
