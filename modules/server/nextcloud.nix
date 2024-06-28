{ config, lib, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";
  services = {
    nginx.virtualHosts = {
      "cloud.home.com" = {
        forceSSL = true;
        enableACME = true;
      };

      "docs.home.com" = {
        forceSSL = true;
        enableACME = true;
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
      https = true;
      enableBrokenCiphersForSSE = false;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts mail notes onlyoffice tasks cookbook;
      };

      config = {
        overwriteProtocol = "https";
        dbtype = "pgsql";
        adminuser = "admin";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };
    };

    onlyoffice = {
      enable = true;
      hostname = "docs.home.com";
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
