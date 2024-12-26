{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim = {
      url = "github:nix-community/nixvim";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, nixos-hardware, stylix, nixvim, ... }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
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
        workstation = {
          # Contorls the monitor layout for hyprland
          workspace = [
            "1, monitor:DP-1, default:true"
            "2, monitor:DP-2, default:true"
          ];
          monitor = [
            "DP-1,2560x1080@60,0x1080,1"
            "DP-2,2560x1080@60,0x0,1"
          ];
        };
      };
    in
    {
      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit hardwareConfig;
            inherit pkgs-unstable;
          };
          modules = [
            ./hosts/workstation.nix
            stylix.nixosModules.stylix
            # Using community hardware configurations
            nixos-hardware.nixosModules.common-pc-ssd
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs;
                inherit pkgs-unstable;
                hardwareConfig = hardwareConfig.workstation;
              };
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.codyt = import ./users/cody.nix;
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
            nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
            nixos-hardware.nixosModules.common-pc-ssd
            inputs.sops-nix.nixosModules.sops
          ];
        };
        family = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/family-desktop.nix
            stylix.nixosModules.stylix
            # Using community hardware configurations
            nixos-hardware.nixosModules.common-gpu-intel-sandy-bridge
            inputs.sops-nix.nixosModules.sops
          ];
        };
      };
    };
}
