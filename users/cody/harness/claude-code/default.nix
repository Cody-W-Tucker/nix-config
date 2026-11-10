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
  programs.claude-code = {
    enable = true;
    package = llmPkgs.claude-code;
    enableMcpIntegration = true;
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
