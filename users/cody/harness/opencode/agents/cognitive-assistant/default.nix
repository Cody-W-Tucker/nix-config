{ inputs, ... }:

let
  systemPrompt = builtins.readFile inputs.cognitive-assistant.lib.systemPromptFile;
in
{
  imports = [ ./skills ];

  programs.opencode.agents."cognitive-assistant" = ''
    ---
    description: Personalized cognitive assistant grounded in Cody's generated system prompt and support skills.
    mode: primary
    ---
  ''
  + systemPrompt;
}
