{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./agents/logging
    ./agents/knowledge
    ./agents/memory
    ./agents/business
    ./agents/existential
    ./agents/operational
    ./skills/agent-browser
    ./skills/humanizer
    ./tools/rtk
  ];

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    context = ''
      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Common language runtimes (python, node, etc.) are not globally available.

      Use `nix shell` only when a required tool or runtime is missing.

      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js

      Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.

      Memory retrieval:
      - Use enabled read-only Qdrant tools to retrieve durable memories when prior context would materially improve the answer.
      - Always pass an explicit `collection_name`; this harness does not configure a default collection.
      - Store or update memories through the memory subagent rather than writing directly from general agents.
    '';
    settings = {
      autoupdate = false;
      default_agent = "build";
      lsp = {
        nix = {
          command = [ "${lib.getExe pkgs.nil}" ];
          extensions = [ ".nix" ];
          # 'initialization' passes options directly to the LSP during startup
          initialization = {
            formatting = {
              command = [ "${lib.getExe pkgs.nixfmt}" ];
            };
          };
        };
      };
    };
  };
}
