{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.artifacts.alignment) soulFile;
  skillNames = inputs.cognitive-assistant.lib.artifacts.skills.names;
in
{
  imports = [
    ./agents/logging
    ./agents/knowledge
    ./agents/verify-alignment
    ./agents/business
    ./skills/agent-browser
    ./skills/humanizer
    ./skills/cognitive
    ./tools/model-router
    ./tools/rtk
    ./tools/voice
  ];

  home.packages = [
    inputs.cognitive-assistant.packages.${pkgs.stdenv.hostPlatform.system}.verify-alignment
  ];

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    context = builtins.readFile soulFile + ''

      # Environment

      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js

      # Personalization (CA flake skills)

      When personalization would measurably improve results, prioritize these Cognitive Assistant skills over general-purpose ones whenever a CA skill is a fit.
      Only invoke them when they add genuine value — not for routine tasks where plain execution suffices.
      Available skills (cognitive-assistant):
      ${builtins.concatStringsSep "\n" (map (s: "      - ${s}") skillNames)}

      # Speech tool

      When finishing long-running work, you should call the `speak` tool once with a short status line if audible feedback would save the user from reading the full response immediately.
      Do not use it for routine progress updates or normal back-and-forth.
      Good examples:
      - Hey Cody...... Fixed the voice plugin, but I didn't know how you wanted to handle <situation>.
      - Hey Cody...... The build passed, but you may want to review the <specific_choice> I made to accomplish <goal>.
      Keep spoken lines short and avoid code paths.
    '';
    settings = {
      autoupdate = false;
      default_agent = "build";
      permission.external_directory = {
        "/nix/store" = "allow";
        "/nix/store/**" = "allow";
      };
      lsp = {
        nix = {
          command = [ "${lib.getExe pkgs.nil}" ];
          extensions = [ ".nix" ];
          # 'initialization' passes options directly to the LSP during startup
          initialization = {
            formatting = {
              command = [ "${lib.getExe pkgs.nixfmt}" ];
            };
          };
        };
      };
    };
  };
}
