{ den, inputs, ... }:
let
  mkInstantiate = import ./_instantiate.nix { inherit inputs; };
in
{
  # beast tracks nixpkgs-unstable (with unstable Home Manager and nixvim).
  den.hosts.x86_64-linux.beast = {
    instantiate = mkInstantiate inputs.nixpkgs-unstable.lib.nixosSystem;
    channel = "unstable";
    localAi = false;
    users.codyt = { };
    # Unstable Home Manager pairs with nixpkgs-unstable.
    home-manager.module = inputs.home-manager.nixosModules.home-manager;
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
    includes = [
      den.aspects.desktop
      den.aspects.docker
      den.aspects.nvidia
      den.aspects.gaming
      den.aspects.openrazer
      den.aspects.paperless-scanning
      den.aspects.nixvim-desktop
      den.aspects.opencode-remote
    ];

    # Beast's Home Manager role (the desktop comes from den.aspects.desktop; nixvim from den.aspects.nixvim).
    provides.to-users.homeManager = {
      home.stateVersion = "25.05";
    };

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        site = config.codyos.site;
      in
      {
        imports = [
          ./_beast-hardware.nix
        ];

        # ── Machine ─────────────────────────────────────────────────
        # Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | Storage: 2TB NVMe

        # ── Features ────────────────────────────────────────────────
        # nvidia, docker, gaming, openrazer and paperless-scanning are den aspects (this file).

        # Kernel (hardware modules and quirks are in _beast-hardware.nix).
        boot.kernelPackages = pkgs.linuxPackages_latest;

        # ── Nix ─────────────────────────────────────────────────────
        # The NAS pre-builds this host nightly and serves it over Tailscale
        # (modules/server/binary-cache). mkOrder 400 keeps it ahead of the public caches (the shared nix feature uses mkBefore = 500).
        nix.settings = {
          extra-substituters = lib.mkOrder 400 [ "http://${site.hosts.nas.tailscale}:5000" ];
          extra-trusted-public-keys = lib.mkOrder 400 [
            "nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg="
          ];
          # Give up on an unreachable NAS quickly and use the next cache.
          connect-timeout = 5;
        };

        # ── Drives ──────────────────────────────────────────────────
        # Native units keep unavailable NAS shares out of fstab-generator during
        # systemd re-execution: https://github.com/systemd/systemd/issues/44396
        system.fsPackages = [
          pkgs.nfs-utils
          pkgs.cifs-utils
        ];
        systemd.mounts = [
          {
            what = "//${site.hosts.nas.lan}/PaperlessConsume";
            where = "/mnt/paperless-consume";
            type = "cifs";
            options = "guest,uid=${toString config.ids.uids.scanner},gid=${toString config.ids.gids.scanner}";
            mountConfig.TimeoutSec = "10s";
          }
          {
            what = "${site.hosts.nas.lan}:/mnt/projects";
            where = "${site.user.home}/Projects";
            type = "nfs";
            options = "noatime";
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
          }
          {
            what = "${site.hosts.nas.lan}:/mnt/knowledge";
            where = "${site.user.home}/Knowledge";
            type = "nfs";
            options = "noatime";
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
          }
        ];
        systemd.automounts = [
          {
            where = "/mnt/paperless-consume";
            wantedBy = [ "remote-fs.target" ];
            automountConfig.TimeoutIdleSec = "60s";
          }
          {
            where = "${site.user.home}/Projects";
            wantedBy = [ "remote-fs.target" ];
          }
          {
            where = "${site.user.home}/Knowledge";
            wantedBy = [ "remote-fs.target" ];
          }
        ];
        # Share folders (Documents, Music, …) are bind-mounted by syncthing.nix.
        # Networking
        networking = {
          hostName = "beast";
          networkmanager.settings.connection = {
            # MT7925 Bluetooth is more stable when NetworkManager does not power-save Wi-Fi.
            "wifi.powersave" = 2;
          };
          interfaces.eno1.wakeOnLan = {
            enable = true;
            policy = [ "magic" ];
          };
        };

        # Should be the same as the version of NixOS you installed on this machine.
        system.stateVersion = "25.05"; # Did you read the comment?
      };
  };
}
