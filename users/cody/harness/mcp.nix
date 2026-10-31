{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  # Global MCP tools for all agents
  programs.mcp = {
    enable = true;
    servers = {
      open-ontologies = {
        command = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.open-ontologies;
        args = [
          "serve"
          "--data-dir"
          "${config.xdg.dataHome}/open-ontologies/opencode"
          "--storage-mode"
          "memory"
          "--tools-allow"
          "onto_status,onto_validate,onto_load,onto_query,onto_stats,onto_clear,onto_shacl,onto_vocab_check,onto_reason,onto_segment_retrieve"
        ];
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
