{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.nfs.server ];
  den.aspects.beast.includes = [ den.aspects.nfs.client ];

  den.aspects.nfs.server.nixos =
    {
      config,
      ...
    }:

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

  den.aspects.nfs.client.nixos =
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
      system.fsPackages = lib.mkBefore [ pkgs.nfs-utils ];
      systemd.mounts = [
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
          where = "${site.user.home}/Projects";
          wantedBy = [ "remote-fs.target" ];
        }
        {
          where = "${site.user.home}/Knowledge";
          wantedBy = [ "remote-fs.target" ];
        }
      ];
    };
}
