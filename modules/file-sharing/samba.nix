{
  # Samba: the NAS shares folders over SMB (plus WSDD discovery); beast mounts the scanner drop folder.

  den.aspects.samba.server.nixos =
    { config, ... }:

    let
      inherit (config.codyos.site) user;
    in
    {
      services.samba = {
        enable = true;
        openFirewall = true;
        settings = {
          global = {
            "workgroup" = "WORKGROUP";
            "server string" = "smbnix";
            "netbios name" = "smbnix";
            "security" = "user";
            #"use sendfile" = "yes";
            #"max protocol" = "smb2";
            # note: localhost is the ipv6 localhost ::1
            "hosts allow" = "192.168.1. 127.0.0.1 localhost";
            "hosts deny" = "0.0.0.0/0";
            "guest account" = "nobody";
            "map to guest" = "bad user";
          };
          codytHome = {
            "path" = "/mnt/backup/Share";
            "browseable" = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";
            "force user" = user.name;
            "force group" = "users";
          };
          Music = {
            "path" = "/mnt/media/Music";
            "browseable" = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";
            "force user" = user.name;
            "force group" = "media";
          };
          PaperlessConsume = {
            "path" = "/var/lib/paperless/consume";
            "browseable" = "yes";
            "read only" = "no";
            "guest ok" = "yes";
            "force user" = "paperless";
            "force group" = "paperless";
            "create mask" = "0664";
            "directory mask" = "2775";
          };
        };
      };

      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
      };

    };

  den.aspects.samba.client.nixos =
    { config, pkgs, ... }:
    let
      site = config.codyos.site;
    in
    {
      # Native units keep unavailable NAS shares out of fstab-generator during
      # systemd re-execution: https://github.com/systemd/systemd/issues/44396
      system.fsPackages = [ pkgs.cifs-utils ];
      systemd.mounts = [
        {
          what = "//${site.hosts.nas.lan}/PaperlessConsume";
          where = "/mnt/paperless-consume";
          type = "cifs";
          options = "guest,uid=${toString config.ids.uids.scanner},gid=${toString config.ids.gids.scanner}";
          mountConfig.TimeoutSec = "10s";
        }
      ];
      systemd.automounts = [
        {
          where = "/mnt/paperless-consume";
          wantedBy = [ "remote-fs.target" ];
          automountConfig.TimeoutIdleSec = "60s";
        }
      ];
    };
}
