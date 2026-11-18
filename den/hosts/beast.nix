{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.beast.hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [
      {
        workspace = "1";
        monitor = "DP-1";
        default = true;
      }
    ];
    monitor = [
      # Samsung Odyssey G65B: HDR output with SDR brightness tuned for the desktop.
      {
        output = "DP-1";
        mode = "2560x1440@239.97";
        position = "0x0";
        vrr = 3;
        bitdepth = 10;
        cm = "hdr";
        sdrbrightness = 1;
        sdrsaturation = 1;
        sdr_max_luminance = 340;
      }
    ];
    # Suspend after 1 hour of idle
    hypridle.suspendTimeout = 3600;
  };

  den.aspects.beast = {
    includes = [
      den.aspects.base
      den.aspects.desktop
      den.aspects.gaming
      den.aspects.openrazer
      den.aspects.paperless-scanning
    ];

    nixos =
      { config, host, ... }:
      {
        imports = [
          # Unstable Home Manager pairs with nixpkgs-unstable.
          inputs.home-manager.nixosModules.home-manager
          ../../hosts/beast
        ];

        home-manager = {
          extraSpecialArgs = {
            inherit inputs;
            inherit (host) hardwareConfig;
          };
          users.${config.codyos.site.user.name} = {
            home.stateVersion = "25.05";
            imports = [
              ../../users/cody/desktop.nix
              inputs.nixos-secrets.homeModules.default
              inputs.nixvim.homeModules.nixvim
            ];
          };
        };
      };
  };
}
