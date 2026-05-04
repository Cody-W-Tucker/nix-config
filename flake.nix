{
  description = "CodyOS";
  inputs = {
    nixos-hardware = {
      # Provides hardware-specific modules.
      url = "github:NixOS/nixos-hardware/master";
    };

    # Stable packages (mostly for the server).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix = {
      # Managing secrets.
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      # Configures theming for the desktop and cli.
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim = {
      # Configures neovim and related plugins.
      url = "github:nix-community/nixvim";
      # Nixvim tests against their nixpkgs version and we shouldn't follow our own if we want the benefit.
      # inputs.nixpkgs.follows = "nixpkgs-unstable";
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
    whisp-away = {
      # Voice dictation for Linux using OpenAI's Whisper models.
      url = "github:madjinn/whisp-away";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    searcher = {
      # custom perplexity replacement for agentic search
      url = "github:Cody-W-Tucker/searcher";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    googleworkspace-cli = {
      # Google Workspace CLI for Drive, Gmail, Calendar, and related APIs.
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    crm-cli = {
      # Headless CLI-first CRM with a Home Manager module and OpenCode skill.
      url = "github:Cody-W-Tucker/crm.cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    cognitive-assistant = {
      # Generated prompt and skill artifacts for a personalized cognitive assistant.
      url = "github:Cody-W-Tucker/Cognitive-Assistant";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    rlm = {
      # Local Recursive Language Model CLI under active development.
      url = "github:Cody-W-Tucker/rlm";
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
      pkgs = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      # Official NixOS formatter with directory support
      formatter.x86_64-linux = nixpkgs-unstable.legacyPackages.${system}.nixfmt-tree;

      # Custom packages exposed via the flake
      packages.${system} = {
        gh-star-search = pkgs.callPackage ./packages/gh-star-search { };
        llama-cpp-strix = pkgs.callPackage ./packages/llama-cpp-strix { };
      };

      # Builds the different systems
      nixosConfigurations = {
        beast = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/beast.nix ];
        };
        server = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            home-manager-input = inputs.home-manager-stable;
          };
          modules = [ ./hosts/server.nix ];
        };
        aiserver = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/aiserver.nix ];
        };
      };
    };
}
