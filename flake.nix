{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nextmeeting = {
      url = "github:Cody-W-Tucker/nextmeeting-nix?dir=packaging";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-programs-sqlite = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    web-downloader.url = "github:Cody-W-Tucker/web-downloader";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
        };
      };
      pkgs-unstable = import nixpkgs-unstable {
        system = system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = (_: true);
        };
      };
      hardwareConfig = {
        beast = {
          # Controls the monitor layout for hyprland
          workspace = [
            "1, monitor:HDMI-A-3, default:true"
          ];
          monitor = [
            "HDMI-A-3,2560x1440@240,0x0,1,bitdepth,10,cm,hdr"
          ];
        };
        workstation = {
          # Controls the monitor layout for hyprland
          workspace = [
            "1, monitor:DP-4, default:true"
            "2, monitor:HDMI-A-4, default:true"
          ];
          monitor = [
            "DP-4,2560x1080@60,0x1080,1"
            "HDMI-A-4,2560x1080@60,0x0,1"
          ];
        };
      };
    in
    {
      nixosConfigurations = {
        beast = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit hardwareConfig;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/beast.nix
            # Using community hardware configurations
            inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.nixos-hardware.nixosModules.common-pc
            inputs.sops-nix.nixosModules.sops
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs;
                inherit pkgs-unstable;
                inherit system;
                hardwareConfig = hardwareConfig.beast;
              };
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
                inputs.stylix.homeModules.stylix
              ];
              home-manager.users.codyt.imports = [
                ./cody/ui.nix
                ./secrets/home-secrets.nix
                inputs.nixvim.homeManagerModules.nixvim
              ];
            }
          ];
        };
        workstation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit hardwareConfig;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/workstation.nix
            # Using community hardware configurations
            inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.nixos-hardware.nixosModules.common-pc
            inputs.sops-nix.nixosModules.sops
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs;
                inherit pkgs-unstable;
                inherit system;
                hardwareConfig = hardwareConfig.workstation;
              };
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
                inputs.stylix.homeModules.stylix
              ];
              home-manager.users.codyt.imports = [
                ./cody/ui.nix
                ./secrets/home-secrets.nix
                inputs.nixvim.homeManagerModules.nixvim
              ];
            }
          ];
        };
        server = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/server.nix
            # Using community hardware configurations
            inputs.nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.sops-nix.nixosModules.sops
            inputs.vpn-confinement.nixosModules.default
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs;
                inherit pkgs-unstable;
                inherit system;
              };
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
                inputs.stylix.homeModules.stylix
              ];
              home-manager.users.codyt.imports = [
                ./cody/cli.nix
                ./secrets/home-secrets.nix
                inputs.nixvim.homeManagerModules.nixvim
              ];
            }
          ];
        };
        family = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/family-desktop.nix
            inputs.stylix.nixosModules.stylix
            # Using community hardware configurations
            inputs.nixos-hardware.nixosModules.common-gpu-intel-sandy-bridge
            inputs.sops-nix.nixosModules.sops
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs;
                inherit pkgs-unstable;
              };
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.codyt = import ./cody/cli.nix;
            }
          ];
        };
      };
    };
}
