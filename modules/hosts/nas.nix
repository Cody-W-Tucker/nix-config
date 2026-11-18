{ den, inputs, ... }:
let
  mkInstantiate = import ./_instantiate.nix { inherit inputs; };
in
{
  # nas tracks stable nixpkgs (with stable Home Manager and nixvim).
  den.hosts.x86_64-linux.nas = {
    instantiate = mkInstantiate inputs.nixpkgs.lib.nixosSystem;
    channel = "stable";
    localAi = true;
    users.codyt = { };
    # Stable Home Manager pairs with stable nixpkgs.
    home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
    lan = "192.168.1.2";
    tailscale = "100.81.249.65";
  };

  den.aspects.nas = {
    includes = [
      den.aspects.base
      den.aspects.nas-role
      den.aspects.hermes-agent
      den.aspects.llama-swap
      den.aspects.hindsight
      den.aspects.opencode
    ];

    # Nas's Home Manager role: server and stable nixvim (Hermes' HM half comes from
    # den.aspects.hermes-agent).
    provides.to-users.homeManager = {
      home.stateVersion = "25.11";
      imports = [
        ../_legacy/users/cody/server.nix
        # Stable nixvim pairs with stable Home Manager.
        inputs.nixvim-stable.homeModules.nixvim
      ];
    };

    nixos =
      { config, pkgs, ... }:
      let
        site = config.codyos.site;
      in
      {
        # Machine facts for nas (disks and kernel modules are in _nas-hardware.nix).
        # llama-swap and its model catalog are den.aspects.llama-swap.
        imports = [ ./_nas-hardware.nix ];
        # ZFS storage (disks and kernel modules are in _nas-hardware.nix).
        boot = {
          kernelParams = [ "zfs.zfs_arc_max=8589934592" ]; # 8 GiB
          supportedFilesystems = [ "zfs" ];
          zfs.extraPools = [ "backup" ];
          zfs.forceImportRoot = false;
        };

        # ── User bind mounts ─────────────────────────────────────────
        # Bind NAS-local Projects and Knowledge Btrfs subvolumes into the user's
        # home. The Share folders (Documents, Music, …) come from syncthing.nix.
        fileSystems."${site.user.home}/Projects" = {
          device = "/mnt/projects";
          fsType = "none";
          options = [ "bind" ];
        };

        fileSystems."${site.user.home}/Knowledge" = {
          device = "/mnt/knowledge";
          fsType = "none";
          options = [ "bind" ];
        };

        services = {
          # Auto configure usb etc, when plugedin
          udisks2.enable = true;
          tailscale = {
            # Enable IP forwarding so this host can act as a subnet router for the LAN.
            useRoutingFeatures = "server";
            extraSetFlags = [
              "--advertise-routes=${site.lan.subnet}"
              "--accept-dns=false"
            ];
          };
          zfs.autoScrub.enable = true;
          # Monthly Btrfs scrub. One mount per filesystem: the default (every Btrfs
          # mount) would scrub the same disk once per subvolume.
          btrfs.autoScrub = {
            enable = true;
            fileSystems = [
              "/" # boot NVMe: root, home, nix
              "/mnt/appdata" # appdata NVMe: appdata, tmp, projects, knowledge
            ];
          };
        };

        # ── Features ────────────────────────────────────────────────
        codyos = {
          hardware.nvidia = {
            enable = true;
            powerLimit = {
              enable = true;
              watts = 123;
            };
          };
        };
        # hindsight and opencode are den aspects (this file).

        # Networking
        networking = {
          hostName = "nas";
          hostId = "60f0861b";
          # Static LAN address for the NAS so it keeps a predictable IP across router
          # resets. Starlink does not publish a reserved DHCP pool, so we pin the
          # active physical connection instead of relying on a lease.
          useDHCP = false;
          networkmanager.ensureProfiles.profiles."Wired connection 1" = {
            connection = {
              id = "Wired connection 1";
              uuid = "faa5cfb6-2e8f-34f2-981e-194fbc74a105";
              type = "802-3-ethernet";
              interface-name = "enp6s0";
              autoconnect = true;
              autoconnect-priority = 100;
            };
            ipv4 = {
              method = "manual";
              addresses = "${site.hosts.nas.lan}/${toString site.lan.prefixLength}";
              gateway = site.lan.gateway;
              may-fail = false;
            };
            ipv6 = {
              # Leave IPv6 dynamic (SLAAC/RA) as before; only IPv4 is pinned static.
              method = "auto";
            };
          };
          firewall = {
            interfaces.tailscale0.allowedTCPPorts = [
              # Hermes API — reachable only over Tailscale (Beast→NAS voice pipeline)
              # Hermes Dashboard — remote web UI, authenticated via basic auth
              8642
              9119
              # llama-swap router — reachable only over Tailscale
              8081
            ];
          };
        };

        # Docker package
        virtualisation.docker.package = pkgs.docker_29;

        # llama-swap (_nas-models.nix) and Hermes (modules/services/hermes-agent/_hm/runtime)
        # put /run/current-system/sw/lib on LD_LIBRARY_PATH and may load CUDA
        # libraries from the toolkit there, so keep it installed on this host.
        environment.systemPackages = [ pkgs.cudaPackages.cudatoolkit ];

        hardware = {
          # NVIDIA GPU (RTX 5060)
          # NVIDIA container toolkit for CUDA container access
          nvidia-container-toolkit.enable = true;
          # Bluetooth support for Home Assistant (prepares for future controller)
          bluetooth.enable = true;
        };

        # This value determines the NixOS release from which the default
        # settings for stateful data, like file locations and database versions
        # on your system were taken. It‘s perfectly fine and recommended to leave
        # this value at the release version of the first install of this system.
        # Before changing this value read the documentation for this option
        # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
        system.stateVersion = "26.05"; # Did you read the comment?

      };
  };
}
