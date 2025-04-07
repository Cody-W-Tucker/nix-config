{
  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ];
  services.tailscale.useRoutingFeatures = "server";
  networking.firewall.trustedInterfaces = [ "tailscale0" ];  # Allow traffic from Tailscale
  services.tailscale.advertiseRoutes = [ "192.168.254.254/24" ];  # Replace with your actual LAN subnet
}