{
  mkNginxVhost,
  ...
}:

{
  services = {
    adguardhome = {
      enable = true;
      openFirewall = false;
      port = 8000;
      mutableSettings = false;
      settings = {
        # Integrated DHCP server is not used — DNS only.
        dhcp.enabled = false;

        dns = {
          # Listen on all IPv4 interfaces: covers LAN (192.168.1.2) and Tailscale
          # (100.81.249.65). IPv6 binding is omitted because the prior config was
          # IPv4-only and nothing in the current setup requires it.
          bind_hosts = [ "0.0.0.0" ];
          port = 53;

          # Single-cache architecture: AdGuard's only upstream is the local Unbound
          # recursive resolver (127.0.0.1:5335), which already maintains the cache.
          # A second cache here would double-buffer and serve stale records, so it
          # is disabled.
          cache_enabled = false;

          # Ordinary queries are forwarded to the local Unbound resolver.
          upstream_dns = [ "127.0.0.1:5335" ];

          # Required by the NixOS module when mutableSettings = false. The upstream
          # is a literal IP, so bootstrap DNS is never consulted — no loop risk.
          bootstrap_dns = [ "1.1.1.1" ];

          # Local homehub.tv apex and wildcard resolve to the NAS LAN address.
          rewrites = [
            {
              domain = "homehub.tv";
              answer = "192.168.1.2";
            }
            {
              domain = "*.homehub.tv";
              answer = "192.168.1.2";
            }
          ];
        };
        filters = [
          {
            id = 33;
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt";
            name = "AdGuard Home Registry filter 33";
          }
          {
            id = 34;
            enabled = true;
            url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts";
            name = "StevenBlack porn-only hosts";
          }
        ];
      };
    };
    nginx.virtualHosts = mkNginxVhost {
      host = "adguard.homehub.tv";
      port = 8000;
    };
    unbound = {
      enable = true;
      settings = {
        server = {
          # When only using Unbound as DNS, make sure to replace 127.0.0.1 with your ip address
          # When using Unbound in combination with pi-hole or Adguard, leave 127.0.0.1, and point Adguard to 127.0.0.1:PORT
          interface = [
            "127.0.0.1"
            "::1"
          ];
          port = 5335;
          access-control = [
            "127.0.0.1 allow"
            "::1 allow"
          ];
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
          msg-cache-size = "32m";
          rrset-cache-size = "64m";
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
  };

  networking.firewall = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };

  networking.nameservers = [
    # Add a fallback to ensure server will reboot
    "127.0.0.1" # Local resolver
    "::1" # Local resolver
    "1.1.1.1" # Cloudflare fallback
  ];
}
