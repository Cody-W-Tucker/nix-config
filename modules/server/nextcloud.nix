{ config, lib, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";
  services = {
    nginx.virtualHosts = {
      "homehub.tv" = {
        forceSSL = false;
        enableACME = false;
      };

      "docs.homehub.tv" = {
        forceSSL = false;
        enableACME = false;
      };
    };
    nextcloud = {
      enable = true;
      hostName = "homehub.tv";
      package = pkgs.nextcloud29;
      database.createLocally = true;
      configureRedis = true;
      # Increase the maximum file upload size to avoid problems uploading videos.
      maxUploadSize = "16G";
      https = false;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts mail notes onlyoffice tasks cookbook;
      };

      config = {
        dbtype = "mysql";
        adminuser = "admin";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };
      settings = {
        overwriteprotocol = "http";
        trusted_proxies = [ "127.0.0.1" ];
        trusted_domains = [ "homehub.tv" "docs.homehub.tv" ];
      };
    };

    onlyoffice = {
      enable = true;
      hostname = "docs.homehub.tv";
    };
  };
}
