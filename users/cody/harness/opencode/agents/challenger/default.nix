{ inputs, ... }:

let
  soul = inputs.cognitive-assistant.lib.artifacts.alignment.agentSouls.challenger;
in
{
  programs.opencode.agents.challenger = ''
    ---
    description: Cognitive-assistant challenger — steelman the idea, then surface the strongest objection and the test that settles it.
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
