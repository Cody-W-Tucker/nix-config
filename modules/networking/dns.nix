{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.dns ];

  den.aspects.dns.nixos =
    {
      config,
      inputs,
      pkgs,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      networking = {
        firewall = {
          allowedUDPPorts = [ 53 ];
          allowedTCPPorts = [ 53 ];
        };
        nameservers = [
          "127.0.0.1"
          "::1"
        ];
      };

      services.unbound = {
        enable = true;
        settings = {
          server = {
            interface = [
              "0.0.0.0"
              "::0"
            ];
            port = 53;
            access-control = [
              "0.0.0.0/0 allow"
              "::0/0 allow"
            ];

            local-zone = [ ''"${domain}." redirect'' ];
            local-data = [ ''"${domain}. A ${config.codyos.site.hosts.nas.lan}"'' ];

            include = [ "${inputs.stevenblack.packages.${pkgs.stdenv.hostPlatform.system}.unbound}/hosts" ];

            log-queries = true;
            log-local-actions = true;

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
    };
}
