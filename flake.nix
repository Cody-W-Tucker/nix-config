{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-secrets.url = "github:Cody-W-Tucker/nixos-secrets";
    flake-programs-sqlite = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim-stable = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim.url = "github:nix-community/nixvim";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    nextmeeting = {
      url = "github:Cody-W-Tucker/nextmeeting-nix?dir=packaging";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    ai-usagebar = {
      url = "github:akitaonrails/ai-usagebar";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    googleworkspace-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    cognitive-assistant = {
      url = "github:Cody-W-Tucker/Cognitive-Assistant";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        llm-agents.follows = "llm-agents";
        ai-data-extractor.inputs.nixpkgs.follows = "nixpkgs-unstable";
      };
    };
    workflow = {
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
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    den.url = "github:denful/den/v0.20.0";
    import-tree.url = "github:vic/import-tree";
    stevenblack = {
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

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
