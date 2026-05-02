{ inputs, ... }:

let
  systemPrompt = builtins.readFile inputs.cognitive-assistant.lib.operational.systemPromptFile;
in
{
  imports = [ ./skills ];

  programs.opencode.agents.operational = ''
    ---
    description: Operational execution agent grounded in Cody's generated operational profile and dynamic support skills.
    mode: primary
    ---
  ''
  + systemPrompt;
}
