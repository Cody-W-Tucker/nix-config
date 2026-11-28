{ den, inputs, ... }:
{
  den = {
    aspects.nix = {
      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          nixpkgs.config.allowUnfree = true;

          sops = {
            secrets."github-nix-secrets-read" = { };
            templates."nix-access-tokens.conf" = {
              content = ''
                access-tokens = github.com=${config.sops.placeholder."github-nix-secrets-read"}
              '';
              owner = "root";
              group = "wheel";
              mode = "0440";
            };
          };

          nix = {
            channel.enable = false;
            extraOptions = ''
              !include ${config.sops.templates."nix-access-tokens.conf".path}
            '';
            settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              extra-substituters = lib.mkBefore [
                "https://cache.numtide.com"
                "https://nix-community.cachix.org"
              ];
              extra-trusted-public-keys = lib.mkBefore [
                "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
            };
            optimise.automatic = true;
            gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 7d";
            };
          };

          environment.systemPackages = [
            pkgs.check-imports
            pkgs.update
          ];

          programs.command-not-found = {
            enable = true;
            dbPath = pkgs.callPackage "${inputs.flake-programs-sqlite}/programs-sqlite.nix" {
              nixpkgsRev = config.system.nixos.revision;
            };
          };
        };

      homeManager.programs.zsh.shellAliases = {
        upgrade = ''
          cd /etc/nixos &&
          sudo nix flake update &&
          sudo nixos-rebuild switch
        '';
        gcCleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      };

      overlay.nixos =
        { self, ... }:
        {
          nixpkgs.overlays = [ self.overlays.default ];
        };
    };

    default.includes = [ den.aspects.nix ];
    schema.host.includes = [ den.aspects.nix.overlay ];
  };
}
