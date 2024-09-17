{ config, ... }:

# Broken due to replacing extraConfig with settings.
{
  # services.samba = {
  #   enable = true;
  #   securityType = "user";
  #   openFirewall = true;
  #   extraConfig = ''
  #     workgroup = WORKGROUP
  #     server string = smbnix
  #     netbios name = smbnix
  #     security = user 
  #     #use sendfile = yes
  #     #max protocol = smb2
  #     # note: localhost is the ipv6 localhost ::1
  #     hosts allow = 192.168.254. 127.0.0.1 localhost
  #     hosts deny = 0.0.0.0/0
  #     guest account = nobody
  #     map to guest = bad user
  #   '';
  #   shares = {
  #     codytHome = {
  #       path = "/mnt/hdd/Share";
  #       browseable = "yes";
  #       "read only" = "no";
  #       "guest ok" = "no";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #       "force user" = "codyt";
  #       "force group" = "users";
  #     };
  #     media = {
  #       path = "/mnt/hdd/Media";
  #       browseable = "yes";
  #       "read only" = "no";
  #       "guest ok" = "no";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #       "force user" = "codyt";
  #       "force group" = "users";
  #     };
  #     photos = {
  #       path = "/mnt/hdd/Photos";
  #       browseable = "yes";
  #       "read only" = "no";
  #       "guest ok" = "no";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #       "force user" = "codyt";
  #       "force group" = "users";
  #     };
  #   };
  # };

  # services.samba-wsdd = {
  #   enable = true;
  #   openFirewall = true;
  # };

  # Syncthing backup
  services.syncthing.settings.folders."share" = {
    path = "/mnt/hdd/Share";
    devices = [ "server" "workstation" ];
  };
}
