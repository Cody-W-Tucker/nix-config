{ den, ... }:
{
  # Git: the system package, plus the user's identity and settings, delta as the pager,
  # GitHub CLI and lazygit. Registered on every host and user.
  den.aspects.git = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
      };

    homeManager =
      { osConfig, ... }:
      {
        programs = {
          zsh.shellAliases.gg = "lazygit";
          delta = {
            enable = true;
            enableGitIntegration = true;
            options = {
              decorations = {
                commit-decoration-style = "bold yellow box ul";
                file-decoration-style = "none";
                file-style = "bold yellow ul";
              };
              features = "decorations";
              whitespace-error-style = "22 reverse";
            };
          };
          gh = {
            # Enable GitHub CLI
            enable = true;
          };
          git = {
            enable = true;
            ignores = [
              "tmp"
              ".nix-shell"
              ".direnv/"
              "__pycache__/"
            ];
            settings = {
              user = {
                name = "Cody W Tucker";
                inherit (osConfig.codyos.site.user) email;
              };
              alias.st = "status";
              init.defaultBranch = "main";
              pull.rebase = true;
              push.autoSetupRemote = true;
              core.editor = "nvim";
              color = {
                ui = "auto";
                branch = "auto";
                diff = "auto";
                status = "auto";
              };
            };
          };
          lazygit = {
            enable = true;
            settings = {
              gui.paging = {
                colorArg = "always";
                paging = "delta --dark --paging=never";
              };
            };
          };
        };
      };
  };

  den.default.includes = [ den.aspects.git ];
}
