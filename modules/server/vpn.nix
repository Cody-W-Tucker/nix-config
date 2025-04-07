{
  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ];
  services.tailscale.useRoutingFeatures = "server";
}