{
  den.aspects.harness.homeManager =
    { lib, pkgs, ... }:
    let
      server = {
        command = lib.getExe pkgs.ast-grep;
        args = [ "lsp" ];
      };
    in
    {
      home.packages = [ pkgs.ast-grep ];

      programs.opencode.settings.lsp.no-comments = {
        command = [ server.command ] ++ server.args;
        extensions = [ ".nix" ];
      };

      codyos.harness.claudePlugins.no-comments = pkgs.linkFarm "no-comments-claude-plugin" {
        ".claude-plugin/plugin.json" = pkgs.writers.writeJSON "plugin.json" {
          name = "no-comments";
          version = "1.0.0";
          description = "Reports Nix comments as errors through the ast-grep language server.";
          author.name = "codyos";
        };
        ".lsp.json" = pkgs.writers.writeJSON "lsp.json" {
          no-comments = server // {
            extensionToLanguage.".nix" = "nix";
          };
        };
      };
    };
}
