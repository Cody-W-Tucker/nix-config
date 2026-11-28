{ den, ... }:
{
  den.aspects.harness.includes = [ den.aspects.hindsight.client ];

  den.aspects.hindsight.client.homeManager =
    {
      config,
      host,
      inputs,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      hindsightSource = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hindsight.src;

      apiUrl =
        (import ./_endpoints.nix {
          nasTailscale = osConfig.codyos.site.hosts.nas.tailscale;
        }).api
          host.localAi;

      bankMap = {
        "/etc/nixos" = "codyos";
        "${config.home.homeDirectory}/Projects/Cognitive-Assistant" = "cognitive-assistant";
      };

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

      recallHook = script: extra: {
        hooks = [
          (
            {
              type = "command";
              command = "${lib.getExe pkgs.python3} \"\${CLAUDE_PLUGIN_ROOT}/scripts/${script}.py\"";
            }
            // extra
          )
        ];
      };

      claudeHooks = pkgs.writeText "hindsight-claude-hooks.json" (
        builtins.toJSON {
          hooks = {
            UserPromptSubmit = [ (recallHook "recall" { timeout = 25; }) ];
            Stop = [
              (recallHook "retain" {
                timeout = 15;
                async = true;
              })
            ];
          };
        }
      );

      claudePlugin = pkgs.runCommand "claude-plugin-hindsight" { nativeBuildInputs = [ pkgs.patch ]; } ''
        cp -R ${hindsightSource}/hindsight-integrations/claude-code "$out"
        chmod -R u+w "$out"
        # programs.mcp below already registers Hindsight; drop the plugin's local copy
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
      programs.mcp.servers.hindsight.url = "${apiUrl}/mcp/";
      xdg.configFile."opencode/plugins/hindsight.ts".source = opencodePlugin;
      codyos.harness.claudePlugins.hindsight = claudePlugin;
    };
}
