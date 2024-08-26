{
  description = "CodyOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim = {
      url = "github:nix-community/nixvim";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, sops-nix, nixos-hardware, stylix, nixvim, ... }:
    let
      system = "x86_64-linux";
      hardwareConfig = {
        workstation = {
          workspace = [
            "1, monitor:DP-4, default:true"
            "2, monitor:HDMI-A-3, default:true"
          ];
          monitor = [
            "HDMI-A-3,2560x1080@60,0x0,1"
            "DP-4,2560x1080@60,0x1080,1"
          ];
        };
      };
    in
    {
      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          system = system;
          specialArgs = {
            inherit inputs; inherit hardwareConfig;
          };
          modules = [
            ./hosts/workstation.nix
            stylix.nixosModules.stylix
            # Using community hardware configurations
            nixos-hardware.nixosModules.common-pc-ssd
            nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit inputs; hardwareConfig = hardwareConfig.workstation;
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.codyt = import ./home.nix;
            }
          ];
        };
        family = nixpkgs.lib.nixosSystem {
          system = system;
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
        server = nixpkgs.lib.nixosSystem {
          system = system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/server.nix
            # Using community hardware configurations
            nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
            nixos-hardware.nixosModules.common-pc-ssd
            inputs.sops-nix.nixosModules.sops
          ];
        };
        server1 = nixpkgs.lib.nixosSystem {
          system = system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/server1.nix
            inputs.sops-nix.nixosModules.sops
          ];
        };
      };
    };
}
