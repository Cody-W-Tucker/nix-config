{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.artifacts.alignment) translationLayer;
  skillNames = inputs.cognitive-assistant.lib.artifacts.skills.names;
  litellmModels = import ../../../../modules/nas/litellm/models.nix;
in
{
  imports = [
    ./agents/logging
    ./agents/knowledge
    ./agents/business
    ./agents/challenger
    ./agents/scaffolder
    ./agents/verifier
    ./skills/humanizer
    ./skills/cognitive
    ./tools/model-router
    ./tools/rtk
    # ./mcp/mealie
  ];

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    context = builtins.readFile translationLayer + ''

      # Environment

      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js

      # Personalization (CA flake skills)

      When personalization would measurably improve results, prioritize these Cognitive Assistant skills over general-purpose ones whenever a CA skill is a fit.
      Only invoke them when they add genuine value — not for routine tasks where plain execution suffices.
      Available skills (cognitive-assistant):
      ${builtins.concatStringsSep "\n" (map (s: "      - ${s}") skillNames)}
    '';
    settings = {
      autoupdate = false;
      default_agent = "build";
      permission.external_directory = {
        "/nix/store" = "allow";
        "/nix/store/**" = "allow";
      };
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
      # ── Self-hosted LiteLLM proxy ─────────────────────────────
      # OpenAI-compatible endpoint (modules/nas/litellm) at
      # ai.homehub.tv/v1. Model IDs come from the shared source of
      # truth. Per plans/litellm-stateless-migration.md §12.2, the gateway
      # is now master-key-only: the provider authenticates with the
      # LITELLM_API_KEY env var (no literal key in Nix or the generated config).
      # NOTE: how LITELLM_API_KEY reaches this session from SOPS is the owner
      # decision (§13 #5) and is intentionally NOT implemented here.
      provider = {
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "litellm";
          options = {
            baseURL = "https://ai.homehub.tv/v1";
          };
          # Model IDs sourced once from the shared catalog.
          models = builtins.listToAttrs (
            map (id: {
              name = id;
              value = {
                name = id;
              };
            }) litellmModels
          );
        };
      };
    };
  };
}
