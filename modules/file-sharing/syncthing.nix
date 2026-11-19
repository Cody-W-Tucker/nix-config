{
  den.aspects.syncthing.nixos =
    { config, lib, ... }:

    let
      inherit (config.codyos.site) user;
      share = "/mnt/backup/Share";
      # Share subfolders bind-mounted into the user's home on every host.
      homeFolders = [
        "Documents"
        "Music"
        "Pictures"
        "Videos"
      ];
    in
    {
      services.syncthing = {
        enable = true;
        user = user.name;
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = true;
        guiAddress = lib.mkDefault "0.0.0.0:8384";
        # syncthing-init PUTs this whole block, which resets unlisted options to
        # Syncthing defaults; keep anything previously chosen in the GUI here.
        settings.options = {
          # Replace the built-in STUN list (which includes stun.miwifi.com, China).
          stunServers = [
            "stun.l.google.com:19302"
            "stun1.l.google.com:19302"
            "stun2.l.google.com:19302"
          ];
          urAccepted = -1; # usage reporting declined
        };
        settings.devices = {
          "beast" = {
            id = "WS3XKRH-JILABRE-NLK2NU6-BGPXTOY-TOO2K75-UYEY7HB-KO7NKAC-I37UGQ3";
          };
          "nas" = {
            id = "STU55DV-U3QK2RL-7UE5IGR-PRHOSQU-4SK4JUW-Y5YJP5R-IQLNAH2-QXAQBQQ";
          };
        };
      };

      # Sync and discovery ports are opened by openDefaultPorts. The web GUI is
      # reachable over Tailscale only: the NAS nginx proxies beast-syncthing.${domain}
      # to Beast's Tailscale address, and nas-syncthing.${domain} to the NAS locally.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8384 ];
      systemd.tmpfiles.rules = [
        "d /mnt 0755 root root - -"
        "d /mnt/backup 0755 ${user.name} users - -"
        "d ${share} 0755 ${user.name} users - -"
      ];

      # Map Share subfolders into the home directory one by one, so the rest of
      # the home directory stays outside Syncthing.
      fileSystems = lib.genAttrs' homeFolders (
        name:
        lib.nameValuePair "${user.home}/${name}" {
          device = "${share}/${name}";
          fsType = "none";
          options = [
            "bind"
            "nofail"
          ]
          # Where /mnt/backup is a ZFS pool (NAS), its datasets are mounted by
          # zfs-mount.service rather than .mount units, so order after it.
          ++ lib.optionals config.boot.zfs.enabled [
            "x-systemd.requires=zfs-mount.service"
            "x-systemd.after=zfs-mount.service"
          ];
        }
      );

      # Shared folder, identical on every host that imports this module.
      services.syncthing.settings.folders."Share" = {
        path = share;
        devices = [
          "beast"
          "nas"
        ];
        ignorePatterns = [
          "node_modules"
          "npm"
          "pnpm"
          ".pnpm-store"
          ".git"
          ".venv/"
          ".bundle/"
          ".next/"
          "tmp/"
          "__pycache__/"
          ".turbo/"
          ".trash/"
        ];
      };
    };

  # Opt-in (nas): the web UIs of both hosts behind the NAS nginx, reachable over
  # Tailscale only (see the firewall note above).
  den.aspects.syncthing.nginx.nixos =
    { config, mkNginxVhost, ... }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.NASSyncthing = {
        group = "Network";
        order = 20;
        card = {
          href = "https://nas-syncthing.${domain}";
          icon = "syncthing";
          description = "File Synchronization - NAS";
        };
      };

      codyos.homepage.cards.BeastSyncthing = {
        group = "Network";
        order = 30;
        card = {
          href = "https://beast-syncthing.${domain}";
          icon = "syncthing";
          description = "File Synchronization - Beast";
        };
      };

      services.nginx = {
        upstreams = {
          nas_syncthing = {
            servers = {
              "127.0.0.1:8384" = { };
            };
          };
          beast_syncthing = {
            servers = {
              "${config.codyos.site.hosts.beast.tailscale}:8384" = { };
            };
          };
        };
        virtualHosts =
          mkNginxVhost {
            host = "beast-syncthing.${domain}";
            locations = {
              "/" = {
                proxyPass = "http://beast_syncthing/";
              };
            };
          }
          // mkNginxVhost {
            host = "nas-syncthing.${domain}";
            locations = {
              "/" = {
                proxyPass = "http://nas_syncthing/";
              };
            };
          };
      };
    };
}
