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
    stylix = {
      # Configures theming for the desktop and cli.
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim = {
      # Configures neovim and related plugins.
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
  };

  outputs =
    inputs@{
      self,
      nixpkgs-unstable,
      ...
    }:
    let
      system = "x86_64-linux";
      specialArgs = { inherit inputs self; };
      pkgs = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      # Official NixOS formatter with directory support
      formatter.x86_64-linux = nixpkgs-unstable.legacyPackages.${system}.nixfmt-tree;

      # Custom packages exposed via the flake
      packages.${system} = {
        headroom-ai = pkgs.callPackage ./packages/headroom-ai { };
        llama-cpp-strix = pkgs.callPackage ./packages/llama-cpp-strix { };
      };

      # Builds the different systems
      nixosConfigurations = {
        beast = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/beast.nix ];
        };
        server = inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/server.nix ];
        };
        aiserver = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system specialArgs;
          modules = [ ./hosts/aiserver.nix ];
        };
      };
    };
}
