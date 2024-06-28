{ config, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud29;
    hostName = "192.168.254.25";
    config.adminpassFile = "/etc/nextcloud-admin-pass";
    configureRedis = true;
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
