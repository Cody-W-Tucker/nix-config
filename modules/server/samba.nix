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
        "path" = "/mnt/media/Share";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "codyt";
        "force group" = "users";
      };
      Music = {
        "path" = "/mnt/media/Media/Music";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "codyt";
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

  # Syncthing backup
  services.syncthing.settings.folders."share" = {
    path = "/mnt/media/Share";
    devices = [
      "server"
      "workstation"
      "beast"
    ];
  };
}
