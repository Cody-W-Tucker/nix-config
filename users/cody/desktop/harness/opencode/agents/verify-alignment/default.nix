{ inputs, ... }:

let
  prompt = builtins.readFile inputs.cognitive-assistant.lib.alignment.toolSpecs.verifyAlignment;
in
{
  programs.opencode.agents."verify-alignment" = ''
    ---
    description: Run verify-alignment against artifacts using the generated alignment spec.
    mode: subagent
    tools:
      bash: true
    permission:
      edit: deny
      "context7_*": deny
      "nixos-option-search_*": deny
    ---

  ''
  + prompt
  + ''

    ## Agent Procedure

    When asked to verify an artifact, run `verify-alignment` with the relevant native context flags from the request.

    Use examples:

    - `verify-alignment --file path/to/artifact.md`
    - `verify-alignment --stdin < path/to/artifact.md`
    - `verify-alignment --text "artifact text"`

    Do not edit files. Return the verifier result and briefly state the command shape used.
  '';
}
