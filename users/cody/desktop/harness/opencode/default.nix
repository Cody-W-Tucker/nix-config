{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  userPatternSkillNames =
    lib.pipe
      [
        inputs.cognitive-assistant.lib.operational.skillNames
        inputs.cognitive-assistant.lib.existential.skillNames
      ]
      [
        lib.flatten
        lib.unique
        (lib.sort (a: b: a < b))
      ];
  userPatternSkillList = lib.concatMapStringsSep "\n" (name: "- ${name}") userPatternSkillNames;
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

      # User-Pattern Skills

      The following skills map directly to how the user handles specific situations:

      ${userPatternSkillList}

      When alignment depends on understanding how the user thinks, acts, or prefers work to be sequenced, consult these skills.

      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Common language runtimes (python, node, etc.) are not globally available.

      Use `nix shell` only when a required tool or runtime is missing.

      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js

      Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.

      When finishing substantial work, or when blocked and waiting on the user, you may call the `speak` tool once with a short status line if audible feedback would save the user from reading the full response immediately.
      Use it sparingly: substantial completions, important blockers, or long-running work finishing in the background.
      Do not use it for routine progress updates or normal back-and-forth.
      Good examples:
      - Fixed the voice plugin, but we can still tune when it speaks.
      - The build passed, but we should still verify the runtime path.
      Keep spoken lines under about 120 characters and avoid code paths unless they matter.
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
