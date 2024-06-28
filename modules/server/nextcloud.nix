{ config, lib, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";
  services = {
    nginx.virtualHosts = {
      "cloud.home.com" = {
        forceSSL = false;
        enableACME = false;
      };

      "docs.home.com" = {
        forceSSL = false;
        enableACME = false;
      };
    };
    nextcloud = {
      enable = true;
      hostName = "cloud.home.com";
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
        dbtype = "pgsql";
        adminuser = "admin";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };
      settings.overwriteprotocol = "http";
    };

    onlyoffice = {
      enable = true;
      hostname = "docs.home.com";
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
