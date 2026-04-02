{
  programs.mcp = {
    enable = true;
    servers = {
      # docs-langchain = {
      #   url = "https://docs.langchain.com/mcp";
      # };
      context7 = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @upstash/context7-mcp"
        ];
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
