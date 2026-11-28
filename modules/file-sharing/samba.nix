{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.samba.server ];

  den.aspects.samba.server.nixos =
    { config, ... }:
    let
      inherit (config.codyos.site) user;
      share = path: group: {
        inherit path;
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = user.name;
        "force group" = group;
      };
    in
    {
      services = {
        samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "server string" = "smbnix";
              "netbios name" = "smbnix";
              "security" = "user";
              "hosts allow" = "192.168.1. 127.0.0.1 localhost";
              "hosts deny" = "0.0.0.0/0";
              "guest account" = "nobody";
              "map to guest" = "bad user";
            };
            codytHome = share "/mnt/backup/Share" "users";
            Music = share "/mnt/media/Music" "media";
          };
        };

        samba-wsdd = {
          enable = true;
          openFirewall = true;
        };
      };
    };
}
