{ config, lib, pkgs, ... }:

{
  sops.secrets = {
    nextcloud-adminpassfile = {
      owner = "nextcloud";
      group = "nextcloud";
    };
  };

  services = {
    nginx.virtualHosts = {
      "cloud.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
      };
    };
    nextcloud = {
      enable = true;
      hostName = "cloud.homehub.tv";
      package = pkgs.nextcloud30;
      database.createLocally = true;
      configureRedis = true;
      # Increase the maximum file upload size to avoid problems uploading videos.
      maxUploadSize = "16G";
      https = true;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts mail notes richdocuments tasks cookbook;
      };

      config = {
        dbtype = "mysql";
        adminuser = "admin";
        adminpassFile = config.sops.secrets.nextcloud-adminpassfile.path;
      };
      settings = {
        overwriteprotocol = "https";
        trusted_proxies = [ "127.0.0.1" ];
        trusted_domains = [ "cloud.homehub.tv" "docs.homehub.tv" ];
      };
    };
  };
}
