{
  config,
  inputs,
  pkgs,
  ...
}:

let
  site = config.codyos.site;
in

{
  imports = [
    ../../modules/system/base.nix
    ../../modules/hardware/baseline.nix
    ../../modules/nas
    inputs.workflow.nixosModules.default
    ./hardware-configuration.nix
    ./models.nix
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
  ];

  # ZFS storage (disks and kernel modules are in hardware-configuration.nix).
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
    hindsight.enable = true;
    opencode.enable = true; # web server for opencode
  };

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

  # llama-swap (models.nix) and Hermes (modules/services/hermes-agent/runtime)
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

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };
    users.${site.user.name} = {
      home.stateVersion = "25.11";
      imports = [
        ../../users/cody/server.nix
        ../../modules/services/hermes-agent
        inputs.nixos-secrets.homeModules.default
        inputs.nixvim-stable.homeModules.nixvim
      ];
    };
  };

  # Hermes runs as a Home Manager user service, so its backup wiring lives at
  # the NixOS level here: the state and CRM SQLite files are consistently
  # exported by Restic's pre-backup step, while remaining Hermes state is a
  # direct Restic input (live *.db* files stay excluded centrally).
  nas.backups.sqlite = [
    {
      name = "hermes";
      source = "${site.user.home}/.local/share/hermes/state.db";
      filename = "state.db";
    }
    {
      name = "hermes";
      source = "${site.user.home}/.local/share/hermes/crm/crm.db";
      filename = "crm.db";
    }
  ];
  nas.backups.dataDirectories = [
    "${site.user.home}/.local/share/hermes"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
