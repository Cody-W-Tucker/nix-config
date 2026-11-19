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
    ai-usagebar = {
      url = "github:akitaonrails/ai-usagebar";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
    den = {
      # Dendritic aspect library; owns nixosConfigurations (see modules/README.md).
      url = "github:denful/den/v0.20.0";
    };
    import-tree = {
      # Loads every module under modules/ (paths containing `/_` are skipped).
      url = "github:vic/import-tree";
    };
    stevenblack = {
      # StevenBlack ads/malware blocklist, consumed directly as the upstream
      # Unbound include via packages.<system>.unbound (a generated local-zone
      # always_nxdomain fragment). No wrapper module.
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  # Every output comes from the Den/flake-level modules under modules/ (paths containing
  # `/_` are skipped): nixosConfigurations from modules/hosts/, the rest from modules/flake/.
  # Den also publishes its own `denful` aspect export; it is not part of this flake's API.
  outputs =
    inputs:
    removeAttrs
      (inputs.nixpkgs.lib.evalModules {
        modules = [
          inputs.den.flakeModule
          (inputs.import-tree ./modules)
        ];
        specialArgs = { inherit inputs; };
      }).config.flake
      [ "denful" ];
}
