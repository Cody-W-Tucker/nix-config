# Hindsight auto-retain for OpenCode and Claude Code.
#
# Recall stays on demand through the shared Hindsight MCP server in ../../mcp.nix;
# this module covers the write-back half so coding sessions populate the memory
# banks without manual retain calls.
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
    if osConfig.networking.hostName == "nas" then
      "http://127.0.0.1:8888"
    else
      "http://${osConfig.codyos.site.hosts.nas.tailscale}:18083";

  # Map known repositories to the existing Hindsight banks; other projects
  # write to a bank named after their git root directory.
  bankMap = {
    "/etc/nixos" = "codyos";
    "${config.home.homeDirectory}/Projects/Cognitive-Assistant" = "cognitive-assistant";
  };

  opencodePlugin = pkgs.replaceVars ./opencode-retain.js {
    inherit apiUrl;
    bankMap = builtins.toJSON bankMap;
  };

  claudeSettings = pkgs.writeText "hindsight-claude-settings.json" (
    builtins.toJSON {
      hindsightApiUrl = apiUrl;
      autoRecall = false;
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

  # Only the Stop hook is registered: recall is off and the server is external,
  # so SessionStart, UserPromptSubmit, and SessionEnd have nothing to do.
  claudeHooks = pkgs.writeText "hindsight-claude-hooks.json" (
    builtins.toJSON {
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
