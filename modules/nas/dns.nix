{
  config,
  lib,
  pkgs,
  ...
}:

let
  stevenblackCategories = [
    "ads"
    "fakenews"
    "gambling"
    "porn"
    "social"
  ];
  stevenblackHosts = lib.concatMapStringsSep " " (
    category: "${lib.getOutput category config.networking.stevenblack.package}/hosts"
  ) stevenblackCategories;
  stevenblackWhitelist = lib.concatStringsSep " " config.networking.stevenblack.whitelist;
  unboundBlocklist = pkgs.runCommand "unbound-stevenblack-blocklist.conf" { } ''
    printf 'server:\n' > "$out"
    ${pkgs.gawk}/bin/awk -v whitelist=${lib.escapeShellArg stevenblackWhitelist} '
      BEGIN {
        split(whitelist, allowed, " ")
        for (i in allowed) {
          whitelistDomain[allowed[i]] = 1
        }
      }
      /^(0\.0\.0\.0|127\.0\.0\.1)[[:space:]]+/ && !whitelistDomain[$2] && !seen[$2]++ {
        printf "  local-zone: \"%s.\" always_nxdomain\n", $2
      }
    ' ${stevenblackHosts} >> "$out"
  '';
in
{
  networking = {
    stevenblack = {
      enable = true;
      block = [
        "fakenews"
        "gambling"
        "porn"
        "social"
      ];
    };
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
      include = [ "${unboundBlocklist}" ];
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
