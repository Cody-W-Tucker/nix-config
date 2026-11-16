{ inputs, pkgs, ... }:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  codyos.harness.plugins.rtk = {
    packages = [ llmPkgs.rtk ];
    opencode.file = "${llmPkgs.rtk}/libexec/rtk/hooks/opencode/rtk.ts";
    claudeCode.hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = "${llmPkgs.rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
          }
        ];
      }
    ];
    context = ''
      you may see `rtk` prepended or rewritten in your tool calls, this is by design to save tokens. `rtk` returns only the minimum, viable context for long tool calls.

      you can disreguard `rtk` as an issue unless directly asked to investigate `rtk` by the user.
    '';
  };
}
