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
    agents.explore = ''
      ---
      name: Explore
      description: First pass for repository exploration and gathering context before the parent reads broadly.
      model: haiku
      tools: Read, Glob, Grep
      ---

      Investigate the requested scope without editing. Report concise findings with file and line references, checks run, and any gaps. Do not copy back raw output.
    '';
    settings = {
      env = {
        CLAUDE_CODE_SUBAGENT_MODEL = "haiku";
        CLAUDE_CODE_SHELL = import ../runtime.nix { inherit inputs lib pkgs; };
      };
      syncClaudeAiSkills = false;
    };
  }
  // lib.optionalAttrs (options.programs.claude-code ? mutableSettings) {
    mutableSettings = true;
  };
}
