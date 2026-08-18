{ inputs, ... }:

let
  soul = inputs.cognitive-assistant.lib.artifacts.alignment.agentSouls.scaffolder;
in
{
  programs.opencode.agents.scaffolder = ''
    ---
    description: Cognitive-assistant scaffolder — turn circling into a bounded option set with honest tradeoffs and one dated next move.
    mode: subagent
    tools:
      bash: true
    permission:
      edit: deny
      "context7_*": deny
      "nixos-option-search_*": deny
    ---

  ''
  + soul;
}
