{
  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ];
  services.tailscale.useRoutingFeatures = "server";
  networking.firewall.trustedInterfaces = [ "tailscale0" ];  # Allow traffic from Tailscale
}