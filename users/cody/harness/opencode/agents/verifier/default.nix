{ inputs, ... }:

let
  soul = inputs.cognitive-assistant.lib.artifacts.alignment.agentSouls.verifier;
in
{
  programs.opencode.agents.verifier = ''
    ---
    description: Cognitive-assistant verifier — check claims against their sources independently and bound what can be claimed from what was inspected.
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
