{
  services.adguardhome = {
    enable = true;
    openFirewall = false;
    port = 8000;
  };
  services.nginx.virtualHosts."adguard.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:8000";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # When only using Unbound as DNS, make sure to replace 127.0.0.1 with your ip address
        # When using Unbound in combination with pi-hole or Adguard, leave 127.0.0.1, and point Adguard to 127.0.0.1:PORT
        interface = [ "127.0.0.1" "::1" ];
        port = 5335;
        access-control = [ "127.0.0.1 allow" "::1 allow" ];
        # Based on recommended settings in https://docs.pi-hole.net/guides/dns/unbound/#configure-unbound
        harden-glue = true;
        harden-dnssec-stripped = true;
        use-caps-for-id = false;
        edns-buffer-size = 1232;

        # Custom settings
        hide-identity = true;
        hide-version = true;

        # Speed improvements
        num-threads = 4;
        msg-cache-size = "512m";
        rrset-cache-size = "1024m";
        cache-max-ttl = 14400;
        cache-min-ttl = 300;
        prefetch = true;
        prefetch-key = true;
        minimal-responses = true;
        so-rcvbuf = "4m";
        so-sndbuf = "4m";
      };
      forward-zone = [ ]; # leave empty for full recursive
    };
  };

  # Networking
  networking.firewall = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };

  # Add a fallback to ensure server will reboot
  networking.nameservers = [
    "127.0.0.1" # Local resolver
    "::1" # Local resolver
    "1.1.1.1" # Cloudflare fallback
  ];
}
