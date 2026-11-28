{
  den.hosts.x86_64-linux.nas = {
    channel = "stable";
    localAi = true;
    nvidiaPowerLimit = 123;
    users.codyt = { };
    lan = "192.168.1.2";
    tailscale = "100.81.249.65";
  };

  den.aspects.nas = {
    provides.to-users.homeManager.home.stateVersion = "25.11";

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
        imports = [ ./_nas-hardware.nix ];
        boot = {
          kernelParams = [ "zfs.zfs_arc_max=8589934592" ];
          supportedFilesystems = [ "zfs" ];
          zfs.extraPools = [ "backup" ];
          zfs.forceImportRoot = false;
        };

        fileSystems = lib.genAttrs' [ "Projects" "Knowledge" ] (
          folder:
          lib.nameValuePair "${site.user.home}/${folder}" {
            device = "/mnt/${lib.toLower folder}";
            fsType = "none";
            options = [ "bind" ];
          }
        );

        services = {
          udisks2.enable = true;
          tailscale = {
            useRoutingFeatures = "server";
            extraSetFlags = [
              "--advertise-routes=${site.lan.subnet}"
              "--accept-dns=false"
            ];
          };
          zfs.autoScrub.enable = true;
          btrfs.autoScrub = {
            enable = true;
            fileSystems = [
              "/"
              "/mnt/appdata"
            ];
          };
        };

        networking = {
          hostName = "nas";
          hostId = "60f0861b";
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
            ipv6.method = "auto";
          };
        };
        virtualisation.docker.package = pkgs.docker_29;

        environment.systemPackages = [ pkgs.cudaPackages.cudatoolkit ];

        hardware = {
          nvidia-container-toolkit.enable = true;
          bluetooth.enable = true;
        };

        system.stateVersion = "26.05";

      };
  };
}
