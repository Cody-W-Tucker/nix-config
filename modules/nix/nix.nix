{ den, inputs, ... }:
{
  # Nix itself: package manager settings (unfree, flakes, caches, GitHub access
  # token, GC), the shared overlay, repo maintenance commands and command-not-found.
  den.aspects.nix.nixos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      nixpkgs.config.allowUnfree = true;

      # The flake's shared overlay (see modules/flake/_overlay.nix); the packages
      # themselves live in packages/<name>/ and reach pkgs through it.
      nixpkgs.overlays = [ self.overlays.default ];

      sops.secrets."github-nix-secrets-read" = { };
      sops.templates."nix-access-tokens.conf" = {
        content = ''
          access-tokens = github.com=${config.sops.placeholder."github-nix-secrets-read"}
        '';
        owner = "root";
        group = "wheel";
        mode = "0440";
      };

      nix = {
        # Flakes-only hosts: no nix-channel, and no stale channel entry in NIX_PATH.
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
        # Deduplicate the store on a timer rather than during every build.
        optimise.automatic = true;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };

      # Repo maintenance commands installed system-wide.
      environment.systemPackages = [
        pkgs.check-imports
        pkgs.update
        (import "${inputs.workflow}/packages.nix" { inherit pkgs; }).researchState
      ];

      # Enables prompts to install missing packages when running commands
      # The flake's own package is keyed to its single nixpkgs input, so call its
      # builder with this host's nixpkgs revision (stable on nas, unstable on beast).
      programs.command-not-found = {
        enable = true;
        dbPath = pkgs.callPackage "${inputs.flake-programs-sqlite}/programs-sqlite.nix" {
          nixpkgsRev = config.system.nixos.revision;
        };
      };
    };

  den.aspects.nix.homeManager.programs.zsh.shellAliases = {
    pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
    upgrade = ''
      cd /etc/nixos &&
      sudo nix flake update &&
      sudo nixos-rebuild switch
    '';
    gcCleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
  };

  den.default.includes = [ den.aspects.nix ];
}
