# Hindsight auto-retain and auto-recall for OpenCode and Claude Code.
#
# Coding sessions write to the project's memory bank after each turn, and each
# prompt is answered with memories recalled from that bank and the shared user
# bank. The Hindsight MCP server in ../../mcp.nix stays available for explicit
# calls.
{ localAi }:
{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  hindsightSource = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hindsight.src;

  apiUrl =
    (import ../../../../ai/_hindsight-endpoints.nix {
      nasTailscale = osConfig.codyos.site.hosts.nas.tailscale;
    }).api
      localAi;

  # Map known repositories to the existing Hindsight banks; other projects
  # write to a bank named after their git root directory.
  bankMap = {
    "/etc/nixos" = "codyos";
    "${config.home.homeDirectory}/Projects/Cognitive-Assistant" = "cognitive-assistant";
  };

  # Cross-project user preferences, recalled alongside the project bank.
  sharedBank = "cody";

  opencodePlugin = pkgs.replaceVars ./opencode-memory.js {
    inherit apiUrl sharedBank;
    bankMap = builtins.toJSON bankMap;
  };

  claudeSettings = pkgs.writeText "hindsight-claude-settings.json" (
    builtins.toJSON {
      hindsightApiUrl = apiUrl;
      autoRecall = true;
      recallAdditionalBanks = [ sharedBank ];
      autoRetain = true;
      retainMode = "full-session";
      retainEveryNTurns = 1;
      bankMission = "";
      retainToolCalls = false;
      dynamicBankId = true;
      dynamicBankGranularity = [ "project" ];
      directoryBankMap = bankMap;
      enableKnowledgeTools = false;
      upgradeNotice = false;
    }
  );

  # UserPromptSubmit recalls and Stop retains. The server is external, so
  # SessionStart and SessionEnd have nothing to do.
  claudeHooks = pkgs.writeText "hindsight-claude-hooks.json" (
    builtins.toJSON {
      hooks.UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = "${lib.getExe pkgs.python3} \"\${CLAUDE_PLUGIN_ROOT}/scripts/recall.py\"";
              # Two banks, each with a 10 second request timeout.
              timeout = 25;
            }
          ];
        }
      ];
      hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "${lib.getExe pkgs.python3} \"\${CLAUDE_PLUGIN_ROOT}/scripts/retain.py\"";
              timeout = 15;
              async = true;
            }
          ];
        }
      ];
    }
  );

  claudePlugin = pkgs.runCommand "claude-plugin-hindsight" { nativeBuildInputs = [ pkgs.patch ]; } ''
    cp -R ${hindsightSource}/hindsight-integrations/claude-code "$out"
    chmod -R u+w "$out"
    # Shared mcp.nix already registers Hindsight; drop the plugin's local copy
    # and setup wizard so tools and skills are not duplicated.
    rm -rf "$out/.mcp.json" "$out/skills" "$out/tests"
    cp ${claudeSettings} "$out/settings.json"
    cp ${claudeHooks} "$out/hooks/hooks.json"
    # Keep mapped banks consistent across repository subdirectories/worktrees.
    # Remove when upstream directoryBankMap resolves the git root itself.
    patch -d "$out" -p1 < ${./bank-routing.patch}
  '';
in
{
  codyos.harness.plugins.hindsight = {
    opencode.file = opencodePlugin;
    claudeCode.plugin = claudePlugin;
  };
}
