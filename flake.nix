{
  description = "CodyOS";
  inputs = {
    nixos-hardware = {
      # Provides hardware-specific modules.
      url = "github:NixOS/nixos-hardware/master";
    };
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

    # Pinned to a known-good nixpkgs revision, used ONLY for temporary service
    # workarounds (see modules/nas/karakeep.nix and modules/nas/mealie.nix).
    # Do not follow other inputs; this pins an exact commit.
    nixpkgs-prior = {
      url = "github:nixos/nixpkgs/f13ff45afd1bb73e640eaa08a7066dbed07e3238";
    };
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
      # Nixvim tests against their nixpkgs version and we shouldn't follow our own if we want the benefit.
    };
    zen-browser = {
      # Modern web browser based on firefox.
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nextmeeting = {
      # Used to display calendar events and meetings in waybar.
      url = "github:Cody-W-Tucker/nextmeeting-nix?dir=packaging";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents = {
      # Repo that packages various AI tools.
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    litellm-nix = {
      # LiteLLM proxy package and NixOS module (database-backed UI,
      # Prisma migrations, durable prompt/response capture). Pinned
      # against the fork's own nixpkgs per its README.
      url = "github:adeci/litellm-nix";
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
    };
    hermes-agent = {
      # Upstream Hermes Agent flake with package and NixOS module.
      url = "github:NousResearch/hermes-agent";
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
      specialArgs = {
        inherit inputs self;
        home-manager-input = inputs.home-manager;
      };
    in
    {
      # Official NixOS formatter with directory support
      formatter.x86_64-linux = nixpkgs-unstable.legacyPackages.${system}.nixfmt-tree;

      # Builds the different systems
      nixosConfigurations = {
        beast = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/beast ];
        };
        nas = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            home-manager-input = inputs.home-manager-stable;
          };
          modules = [ ./hosts/nas ];
        };
      };
    };
}
