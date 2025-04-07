{
  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];  # Allow traffic from Tailscale
  services.tailscale.useRoutingFeatures = "server";
}