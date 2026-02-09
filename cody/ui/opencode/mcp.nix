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
      qdrant = {
        command = "nix";
        args = [
          "run"
          "nixpkgs#uv"
          "--"
          "uvx"
          "mcp-server-qdrant"
          "--transport"
          "sse"
        ];
        env = {
          QDRANT_URL = "http://localhost:6333";
          COLLECTION_NAME = "ebooks";

          EMBEDDING_PROVIDER = "ollama";
          OLLAMA_MODEL = "nomic-embed-text";
        };
      };
    };
  };
}
