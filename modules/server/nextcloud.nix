{ config, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud29;
    hostName = "home.local";
    config.adminpassFile = "/etc/nextcloud-admin-pass";
    configureRedis = true;
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
