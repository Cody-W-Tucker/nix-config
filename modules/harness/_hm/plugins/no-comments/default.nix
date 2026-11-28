{ lib, pkgs, ... }:

let
  server = {
    command = lib.getExe pkgs.ast-grep;
    args = [ "lsp" ];
  };

  claudePlugin = pkgs.runCommand "no-comments-claude-plugin" { } ''
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
          no-comments = server // {
            extensionToLanguage.".nix" = "nix";
          };
        }
      )
    } $out/.lsp.json
  '';
in
{
  codyos.harness.plugins.no-comments = {
    packages = [ pkgs.ast-grep ];
    claudeCode.plugin = claudePlugin;
  };

  programs.opencode.settings.lsp.no-comments = {
    command = [ server.command ] ++ server.args;
    extensions = [ ".nix" ];
  };
}
