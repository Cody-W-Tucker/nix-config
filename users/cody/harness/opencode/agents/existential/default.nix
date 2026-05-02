{ inputs, ... }:

let
  systemPrompt = builtins.readFile inputs.cognitive-assistant.lib.existential.systemPromptFile;
in
{
  imports = [ ./skills ];

  programs.opencode.agents.existential = ''
    ---
    description: Existential reasoning agent grounded in Cody's generated existential profile and dynamic support skills.
    mode: primary
    ---
  ''
  + systemPrompt;
}
