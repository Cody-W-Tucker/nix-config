{
  # beast tracks nixpkgs-unstable (with unstable Home Manager and nixvim; see channels.nix).
  den.hosts.x86_64-linux.beast = {
    channel = "unstable";
    localAi = false;
    users.codyt = { };
    lan = "192.168.1.3";
    tailscale = "100.108.143.19";
    mac = "60:cf:84:7a:a3:4a";

    hardwareConfig = {
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
  };

  den.aspects.beast = {
    provides.to-users.homeManager = {
      home.stateVersion = "25.05";
    };

    nixos =
      { pkgs, ... }:
      {
        imports = [
          ./_beast-hardware.nix
        ];

        # ── Machine ─────────────────────────────────────────────────
        # Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | Storage: 2TB NVMe

        # Kernel (hardware modules and quirks are in _beast-hardware.nix).
        boot.kernelPackages = pkgs.linuxPackages_latest;
        networking = {
          hostName = "beast";
          networkmanager.settings.connection = {
            # MT7925 Bluetooth is more stable when NetworkManager does not power-save Wi-Fi.
            "wifi.powersave" = 2;
          };
        };

        # Should be the same as the version of NixOS you installed on this machine.
        system.stateVersion = "25.05"; # Did you read the comment?
      };
  };
}
