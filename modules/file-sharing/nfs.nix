{ den, ... }:
{
  den.aspects = {
    nas.includes = [ den.aspects.nfs.server ];
    beast.includes = [ den.aspects.nfs.client ];

    nfs.server.nixos =
      { config, ... }:
      {
        services.nfs.server = {
          enable = true;
          exports = ''
            /mnt/projects ${config.codyos.site.lan.subnet}(rw,sync,no_subtree_check)
            /mnt/knowledge ${config.codyos.site.lan.subnet}(rw,sync,no_subtree_check)
          '';
        };

        networking.firewall.allowedTCPPorts = [ 2049 ];
      };

    nfs.client.nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (config.codyos.site) hosts user;
        folders = [
          "Projects"
          "Knowledge"
        ];
      in
      {
        system.fsPackages = lib.mkBefore [ pkgs.nfs-utils ];
        systemd = {
          mounts = map (folder: {
            what = "${hosts.nas.lan}:/mnt/${lib.toLower folder}";
            where = "${user.home}/${folder}";
            type = "nfs";
            options = "noatime";
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
          }) folders;
          automounts = map (folder: {
            where = "${user.home}/${folder}";
            wantedBy = [ "remote-fs.target" ];
          }) folders;
        };
      };
  };
}
