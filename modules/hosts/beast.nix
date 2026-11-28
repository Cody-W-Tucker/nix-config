{
  den.hosts.x86_64-linux.beast = {
    channel = "unstable";
    localAi = false;
    users.codyt = { };
    lan = "192.168.1.3";
    tailscale = "100.108.143.19";
    mac = "60:cf:84:7a:a3:4a";

    hardwareConfig = {
      workspace = [
        {
          workspace = "1";
          monitor = "DP-1";
          default = true;
        }
      ];
      monitor = [
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
      hypridle.suspendTimeout = 3600;
    };
  };

  den.aspects.beast = {
    provides.to-users.homeManager.home.stateVersion = "25.05";

    nixos =
      { pkgs, ... }:
      {
        imports = [
          ./_beast-hardware.nix
        ];

        boot.kernelPackages = pkgs.linuxPackages_latest;
        networking = {
          hostName = "beast";
          networkmanager.settings.connection."wifi.powersave" = 2;
        };

        system.stateVersion = "25.05";
      };
  };
}
