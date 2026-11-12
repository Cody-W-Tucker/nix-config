{
  description = "CodyOS";
  inputs = {
    # Stable packages (for the NAS).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    sops-nix = {
      # Managing secrets.
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-secrets = {
      # Private flake for SOPS material.
      url = "github:Cody-W-Tucker/nixos-secrets";
    };
    flake-programs-sqlite = {
      # Restores command-not-found (helpful messages when you type a command that isn't installed).
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement = {
      # Creates a service to force applications to use a specific network interface/VPN.
      url = "github:Maroka-chan/VPN-Confinement";
    };

    # Unstable for newer versions of packages (mostly for the desktop).
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      # Configures the user environment and applications.
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager-stable = {
      # Stable Home Manager for hosts that use stable nixpkgs.
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      # Configures theming for the desktop and cli.
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim-stable = {
      # Configures neovim and related plugins (stable, for NAS).
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      # Configures neovim and related plugins.
      url = "github:nix-community/nixvim";
      # Not following nixpkgs: packages come from ours (nixpkgs.useGlobalPackages), so
      # nixvim's own pin only supplies lib, which keeps its tested lib/module compatibility.
    };
    zen-browser = {
      # Modern web browser based on firefox.
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    nextmeeting = {
      # Used to display calendar events and meetings in waybar.
      url = "github:Cody-W-Tucker/nextmeeting-nix?dir=packaging";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents = {
      # Repo that packages various AI tools.
      url = "github:numtide/llm-agents.nix";
      # LLM Agents tests against their nixpkgs version and we shouldn't follow our own if we want the benefit.
    };
    googleworkspace-cli = {
      # Google Workspace CLI for Drive, Gmail, Calendar, and related APIs.
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    cognitive-assistant = {
      # Generated prompt and skill artifacts for a personalized cognitive assistant.
      url = "github:Cody-W-Tucker/Cognitive-Assistant";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.llm-agents.follows = "llm-agents";
      inputs.ai-data-extractor.inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    workflow = {
      # Context and state management for a personalized cognitive assistant.
      url = "github:Cody-W-Tucker/runtime";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    miniflux-curator = {
      url = "github:Cody-W-Tucker/miniflux-curator";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    whisper-diarization = {
      url = "github:Cody-W-Tucker/whisper-diarization";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    hermes-agent = {
      # Upstream Hermes Agent flake with package and NixOS module.
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    stevenblack = {
      # StevenBlack ads/malware blocklist, consumed directly as the upstream
      # Unbound include via packages.<system>.unbound (a generated local-zone
      # always_nxdomain fragment). No wrapper module.
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs-unstable,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs-unstable {
        inherit system;
        overlays = [ self.overlays.default ];
      };
      specialArgs = {
        inherit inputs self;
      };
    in
    {
      # Official NixOS formatter with directory support
      formatter.x86_64-linux = pkgs.nixfmt-tree;

      # Shared overlay; adds local packages and pkgs.unstable (see overlays/default.nix).
      overlays.default = import ./overlays { inherit inputs; };

      # Every packages/<name>/ directory, as built by the overlay above.
      packages.x86_64-linux = builtins.mapAttrs (name: _: pkgs.${name}) (
        pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./packages)
      );

      # Run by `nix flake check` (locally and in CI), alongside evaluating both hosts.
      checks.x86_64-linux =
        let
          lint =
            name: tools: command:
            pkgs.runCommand "check-${name}" { nativeBuildInputs = tools; } ''
              cd ${self}
              ${command}
              touch $out
            '';
        in
        {
          formatting = lint "formatting" [ pkgs.nixfmt pkgs.findutils ] ''
            find . -name '*.nix' -type f -print0 | xargs -0 nixfmt --check
          '';
          statix = lint "statix" [ pkgs.statix ] "statix check --config statix.toml .";
          deadnix = lint "deadnix" [
            pkgs.deadnix
          ] "deadnix --fail --no-lambda-arg --no-lambda-pattern-names .";
          imports = lint "imports" [ pkgs.check-imports ] "check-imports .";
        };

      # Builds the different systems
      nixosConfigurations = {
        beast = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            inputs.home-manager.nixosModules.home-manager
            ./hosts/beast
          ];
        };
        nas = inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            inputs.home-manager-stable.nixosModules.home-manager
            ./hosts/nas
          ];
        };
      };
    };
}
