{
  description = "CodyOS";
  inputs = {
    nixos-hardware = {
      # Provides hardware specific modules.
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
      # For stablity, use nixvim's nixpkgs instead of inputs.
      url = "github:nix-community/nixvim";
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
      # Repo that pacages various ai tools.
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
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
            "DP-1,2560x1440@239.97,0x0,1,bitdepth,10,vrr,2"
          ];
          # Suspend after 2 hours of idle
          hypridle.suspendTimeout = 7200;
        };
        aiserver = {
          # Top monitor should be HDMI
          workspace = [
            "1, monitor:DP-1, default:true"
          ];
          monitor = [
            "DP-1,3840x2160@240,0x0,1.5"
          ];
          # Never suspend
          hypridle.suspendTimeout = null;
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
            inputs.flake-programs-sqlite.nixosModules.programs-sqlite
            ./secrets/secrets.nix
            inputs.home-manager.nixosModules.home-manager
            ./users/home.nix
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  hardwareConfig = hardwareConfig.beast;
                  inherit pkgs-unstable;
                };
                users.codyt = {
                  home.stateVersion = "25.11";
                  nixpkgs.config.allowUnfree = true;
                  imports = [
                    ./users/cody/ui.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeModules.nixvim
                  ];
                };
              };
            }
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
            inputs.home-manager.nixosModules.home-manager
            ./users/home.nix
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs pkgs-unstable;
                };
                users.codyt = {
                  home.stateVersion = "25.11";
                  nixpkgs.config.allowUnfree = true;
                  imports = [
                    ./users/cody/cli.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeModules.nixvim
                  ];
                  home.enableNixpkgsReleaseCheck = false;
                };
              };
            }
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
            inputs.home-manager.nixosModules.home-manager
            ./users/home.nix
            {
              home-manager = {
                extraSpecialArgs = {
                  inherit inputs;
                  hardwareConfig = hardwareConfig.aiserver;
                  inherit pkgs-unstable;
                };
                users.codyt = {
                  home.stateVersion = "25.11";
                  nixpkgs.config.allowUnfree = true;
                  imports = [
                    ./users/cody/ui.nix
                    ./secrets/home-secrets.nix
                    inputs.nixvim.homeModules.nixvim
                  ];
                };
              };
            }
          ];
        };
      };
    };
}
