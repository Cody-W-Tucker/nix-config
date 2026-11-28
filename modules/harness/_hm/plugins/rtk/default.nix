{ inputs, pkgs, ... }:

let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) rtk;
in
{
  codyos.harness.plugins.rtk = {
    packages = [ rtk ];
    opencode.file = "${rtk}/libexec/rtk/hooks/opencode/rtk.ts";
    claudeCode.hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = "${rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
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
