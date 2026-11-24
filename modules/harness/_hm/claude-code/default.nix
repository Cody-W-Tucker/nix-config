{
  inputs,
  lib,
  options,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.claude-code = {
    enable = true;
    package = llmPkgs.claude-code;
    enableMcpIntegration = true;
    settings = {
      env = {
        CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
        CLAUDE_CODE_SHELL = import ../runtime.nix { inherit inputs lib pkgs; };
      };
      syncClaudeAiSkills = false;
    };
  }
  # Guard: Home Manager release-26.05 (NAS) lacks this option. Drop the guard
  # once the NAS is on a Home Manager release that has it.
  // lib.optionalAttrs (options.programs.claude-code ? mutableSettings) {
    # Merge into a writable settings.json so /config and /model keep working.
    mutableSettings = true;
  };
}
