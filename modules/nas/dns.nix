{ inputs, pkgs, ... }:

{
  networking = {
    firewall = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
    nameservers = [
      "127.0.0.1"
      "::1"
      "1.1.1.1"
    ];
  };

  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Serve LAN, Tailscale, containers, and local processes directly.
        interface = [
          "0.0.0.0"
          "::0"
        ];
        port = 53;
        access-control = [
          "0.0.0.0/0 allow"
          "::0/0 allow"
        ];

        # All homehub.tv names resolve to the NAS on the local network.
        local-zone = [ ''"homehub.tv." redirect'' ];
        local-data = [ ''"homehub.tv. A 192.168.1.2"'' ];

        # StevenBlack ads/malware blocklist, generated upstream as a
        # local-zone always_nxdomain fragment and included directly.
        include = [ "${inputs.stevenblack.packages.${pkgs.stdenv.hostPlatform.system}.unbound}/hosts" ];

        harden-glue = true;
        harden-dnssec-stripped = true;
        use-caps-for-id = false;
        edns-buffer-size = 1232;
        hide-identity = true;
        hide-version = true;
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
      forward-zone = [ ];
    };
  };
}
