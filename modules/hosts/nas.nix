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
    # nvidia-smi board power cap (watts); RTX 5060 LP min is 123 W.
    nvidiaPowerLimit = 123;
    users.codyt = { };
    # Stable Home Manager pairs with stable nixpkgs.
    home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
    lan = "192.168.1.2";
    tailscale = "100.81.249.65";
  };

  den.aspects.nas = {
    includes = [
      den.aspects.hermes-agent
      # The NAS service features, in the order of the former server role. Order is load-bearing:
      # den concatenates included modules in reverse include order, so list-valued
      # options (nas.backups.sqlite/dataDirectories, systemd.tmpfiles.rules) follow it.
      # Reordering is safe functionally but changes the Restic job layout and tmpfiles.
      den.aspects.nginx.server
      den.aspects.docker
      den.aspects.docker.oci-backend
      den.aspects.syncthing
      den.aspects.miniflux-curator
      den.aspects.backup-health
      den.aspects.backups
      den.aspects.binary-cache.server
      den.aspects.langfuse
      den.aspects.actual-budget
      den.aspects.dawarich
      den.aspects.home-assistant
      den.aspects.open-webui
      den.aspects.dns
      den.aspects.miniflux
      den.aspects.excalidraw
      den.aspects.homepage
      den.aspects.karakeep
      den.aspects.mealie
      den.aspects.monitoring
      den.aspects.nfs.server
      den.aspects.paperless
      den.aspects.paperless-gpt
      den.aspects.photos
      den.aspects.samba.server
      den.aspects.networking.strict-fail2ban
      den.aspects.syncthing.nginx
      den.aspects.tika
      den.aspects.uptime-kuma
      den.aspects.media
      den.aspects.nvidia
      den.aspects.llama-swap
      den.aspects.hindsight
      den.aspects.opencode
    ];

    # Nas's Home Manager profile (Hermes' HM half comes from den.aspects.hermes-agent, nixvim
    # from den.aspects.nixvim).
    provides.to-users.homeManager = {
      home.stateVersion = "25.11";
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
        # home. The Share folders (Documents, Music, …) come from modules/sync/syncthing.nix.
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
        # nvidia, hindsight and opencode are den aspects (this file).

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

        # llama-swap (_nas-models.nix) and Hermes (modules/ai/hermes-agent/_hm/runtime)
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
