{
  den.aspects.harness.homeManager =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) rtk;

      noComments = {
        command = lib.getExe pkgs.ast-grep;
        args = [ "lsp" ];
      };

      noCommentsClaudePlugin = pkgs.runCommand "no-comments-claude-plugin" { } ''
        mkdir -p $out/.claude-plugin
        cp ${
          pkgs.writeText "plugin.json" (
            builtins.toJSON {
              name = "no-comments";
              version = "1.0.0";
              description = "Reports Nix comments as errors through the ast-grep language server.";
              author.name = "codyos";
            }
          )
        } $out/.claude-plugin/plugin.json
        cp ${
          pkgs.writeText "lsp.json" (
            builtins.toJSON {
              no-comments = noComments // {
                extensionToLanguage.".nix" = "nix";
              };
            }
          )
        } $out/.lsp.json
      '';

      rtkContext = ''
        you may see `rtk` prepended or rewritten in your tool calls, this is by design to save tokens. `rtk` returns only the minimum, viable context for long tool calls.

        you can disreguard `rtk` as an issue unless directly asked to investigate `rtk` by the user.
      '';
    in
    {
      home.packages = [
        rtk
        pkgs.ast-grep
      ];

      xdg.configFile."opencode/plugins/rtk.ts".source = "${rtk}/libexec/rtk/hooks/opencode/rtk.ts";

      codyos.harness.claudePlugins.no-comments = noCommentsClaudePlugin;

      programs = {
        opencode = {
          context = rtkContext;
          settings.lsp.no-comments = {
            command = [ noComments.command ] ++ noComments.args;
            extensions = [ ".nix" ];
          };
        };

        claude-code = {
          context = rtkContext;
          settings.hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "${rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
                }
              ];
            }
          ];
        };
      };
    };
}
