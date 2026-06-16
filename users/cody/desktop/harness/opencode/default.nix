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
    '';
    settings = {
      autoupdate = false;
      default_agent = "build";
      model = "openai/gpt-5.4-fast";
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
