{
  networking.firewall = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    port = 8000;
  };
  services.nginx.virtualHosts."adguard.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
      proxyWebsockets = true;
    };
  };
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # When only using Unbound as DNS, make sure to replace 127.0.0.1 with your ip address
        # When using Unbound in combination with pi-hole or Adguard, leave 127.0.0.1, and point Adguard to 127.0.0.1:PORT
        interface = [ "127.0.0.1" ];
        port = 5335;
        access-control = [ "127.0.0.1 allow" ];
        # Based on recommended settings in https://docs.pi-hole.net/guides/dns/unbound/#configure-unbound
        harden-glue = true;
        harden-dnssec-stripped = true;
        use-caps-for-id = false;
        prefetch = true;
        edns-buffer-size = 1232;

        # Custom settings
        hide-identity = true;
        hide-version = true;
      };
      forward-zone = [
        # Example config with quad9
        {
          name = ".";
          forward-addr = [
            "9.9.9.9#dns.quad9.net"
            "149.112.112.112#dns.quad9.net"
          ];
          forward-tls-upstream = true;  # Protected DNS
        }
      ];
    };
  };
}
