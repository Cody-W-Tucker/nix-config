{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # Should use their nixpkgs
    nixvim.url = "github:nix-community/nixvim/nixos-25.05";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nextmeeting.url = "github:Cody-W-Tucker/nextmeeting-nix?dir=packaging";
    flake-programs-sqlite = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    qdrant-upload = {
      url = "github:Cody-W-Tucker/Qdrant-Upload";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode.url = "github:sst/opencode";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
      hardwareConfig = {
        beast = {
          # Controls the monitor layout for hyprland
          workspace = [ "1, monitor:DP-1, default:true" ];
          monitor = [
            "DP-1,2560x1440@240,0x0,1,bitdepth,10,vrr,2"
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
      # Allow formatter to be used on the flake and built systems
      formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # Builds the different systems
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
            inputs.qdrant-upload.nixosModules.default
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            (
              { config, ... }:
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      inputs
                      pkgs
                      pkgs-unstable
                      system
                      ;
                    hardwareConfig = hardwareConfig.beast;
                  };
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  sharedModules = [
                    inputs.sops-nix.homeManagerModules.sops
                    inputs.stylix.homeModules.stylix
                  ];
                  users.codyt.imports = [
                    ./cody/ui.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeManagerModules.nixvim
                  ];
                };
              }
            )
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
            (
              { config, ... }:
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      inputs
                      pkgs
                      pkgs-unstable
                      system
                      ;
                    hardwareConfig = hardwareConfig.workstation;
                  };
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  sharedModules = [
                    inputs.sops-nix.homeManagerModules.sops
                    inputs.stylix.homeModules.stylix
                  ];
                  users.codyt.imports = [
                    ./cody/ui.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeManagerModules.nixvim
                  ];
                };
              }
            )
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
            (
              { config, ... }:
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      inputs
                      pkgs
                      pkgs-unstable
                      system
                      ;
                  };
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  sharedModules = [
                    inputs.sops-nix.homeManagerModules.sops
                    inputs.stylix.homeModules.stylix
                  ];
                  users.codyt.imports = [
                    ./cody/cli.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeManagerModules.nixvim
                  ];
                };
              }
            )
          ];
        };
        aiserver = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/aiserver.nix
            # Using community hardware nixosConfigurations
            inputs.nixos-hardware.nixosModules.common-pc-ssd
            inputs.nixos-hardware.nixosModules.common-gpu-amd
            inputs.nixos-hardware.nixosModules.common-cpu-amd
            inputs.sops-nix.nixosModules.sops
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            (
              { config, ... }:
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      inputs
                      pkgs
                      pkgs-unstable
                      system
                      ;
                  };
                  useGlobalPkgs = false;
                  useUserPackages = true;
                  backupFileExtension = "backup";
                  sharedModules = [
                    inputs.sops-nix.homeManagerModules.sops
                    inputs.stylix.homeModules.stylix
                  ];
                  users.codyt.imports = [
                    ./cody/cli.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeManagerModules.nixvim
                  ];
                };
              }
            )
          ];
        };
      };
    };
}
