{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./langfuse ];

  programs.claude-code = {
    enable = true;
    package = llmPkgs.claude-code;
    enableMcpIntegration = true;
    # Merge into a writable settings.json so /config and /model keep working.
    mutableSettings = true;
    settings.env.CLAUDE_CODE_SUBAGENT_MODEL = "claude-opus-5-5";
    skills =
      lib.mapAttrs (
        _: skill:
        builtins.replaceStrings [ "compatibility: opencode\n" ] [ "compatibility: claude-code\n" ] skill
      ) config.programs.opencode.skills
      // {
        deja-search = "${llmPkgs.deja-vu.src}/skills/deja-search";
        no-mistakes = "${llmPkgs.no-mistakes.src}/skills/no-mistakes/SKILL.md";
      };
  };
}
