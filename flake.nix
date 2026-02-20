{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
            "DP-1,2560x1440@239.97,0x0,1,bitdepth,10,vrr,3"
          ];
        };
        aiserver = {
          # Top monitor should be HDMI
          workspace = [
            "1, monitor:DP-1, default:true"
          ];
          monitor = [
            "DP-1,3840x2160@240,0x0,1.5"
          ];
        };
      };
    in
    {
      # Allow formatter to be used on the flake and built systems
      formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # Builds the different systems
      nixosConfigurations = {
        # Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070
        beast = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit hardwareConfig;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/beast.nix
            inputs.sops-nix.nixosModules.sops
            inputs.qdrant-upload.nixosModules.default
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager-unstable.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                nixpkgs.config.allowUnfreePredicate = lib.mkDefault (_: true);
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      inputs
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
        # Home server / media / homelab CPU: i7-7000
        server = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/server.nix
            inputs.sops-nix.nixosModules.sops
            inputs.vpn-confinement.nixosModules.default
            ./secrets/secrets.nix
            inputs.home-manager-unstable.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                nixpkgs.config.allowUnfreePredicate = lib.mkDefault (_: true);
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
                  users.codyt = {
                    imports = [
                      ./cody/cli.nix
                      ./secrets/home-secrets.nix
                      inputs.nixvim.homeManagerModules.nixvim
                    ];
                    home.enableNixpkgsReleaseCheck = false;
                  };
                };
              }
            )
          ];
        };
        # Main work workstation. GMKtec-evo2 APU: Strix Halo AI 395+ Max
        aiserver = inputs.nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit hardwareConfig;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/aiserver.nix
            inputs.sops-nix.nixosModules.sops
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager-unstable.nixosModules.home-manager
            (
              { config, lib, ... }:
              {
                nixpkgs.config.allowUnfreePredicate = lib.mkDefault (_: true);
                home-manager = {
                  extraSpecialArgs = {
                    inherit inputs system;
                    hardwareConfig = hardwareConfig.aiserver;
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
      };
    };
}
