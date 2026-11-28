{ den, ... }:
{
  den.aspects = {
    beast.includes = [
      den.aspects.egress-audit
      den.aspects.egress-audit.opensnitch
    ];
    nas.includes = [
      den.aspects.egress-audit
      den.aspects.egress-audit.opensnitch
      den.aspects.egress-audit.server
    ];

    egress-audit = {
      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          internalSuffixes = [
            config.codyos.site.domain
            "in-addr.arpa"
            "ip6.arpa"
            "ts.net"
            "home.arpa"
            "local"
            "lan"
            "localhost"
          ];
          parser = pkgs.writeText "egress-parse.lua" ''
            EGRESS_INTERNAL_SUFFIXES = { ${lib.concatMapStringsSep ", " (s: ''"${s}"'') internalSuffixes} }
            ${builtins.readFile ./_egress-parse.lua}
          '';
          geoDb = "${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb";
          logRule =
            family: set: prefix: flags:
            "ct state new ${family} daddr != @${set} limit rate 50/second burst 500 packets log prefix \"${prefix}: \" level info${flags}";
          skipResolver = lib.optionalString config.services.unbound.enable ''
            meta l4proto { tcp, udp } th dport { 53, 853 } meta skuid unbound return
          '';
          logHostTraffic = !config.services.opensnitch.enable;
          outputChain = ''
            chain output {
              type filter hook output priority filter + 10; policy accept;
              ${skipResolver}
              ${logRule "ip" "private4" "egress-out" " flags skuid"}
              ${logRule "ip6" "private6" "egress-out" " flags skuid"}
            }
          '';
        in
        {
          networking.nftables.tables.egress-audit = {
            family = "inet";
            content = ''
              set private4 {
                type ipv4_addr; flags interval
                elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16,
                             172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255/32 }
              }
              set private6 {
                type ipv6_addr; flags interval
                elements = { ::1/128, fc00::/7, fe80::/10, ff00::/8 }
              }

              ${lib.optionalString logHostTraffic outputChain}
              # Docker containers and other routed traffic never pass the output hook.
              chain forward {
                type filter hook forward priority filter + 10; policy accept;
                ${logRule "ip" "private4" "egress-fwd" ""}
                ${logRule "ip6" "private6" "egress-fwd" ""}
              }
            '';
          };
          networking.nftables.preCheckRuleset = lib.mkIf (logHostTraffic && config.services.unbound.enable) ''
            sed 's/skuid unbound/skuid root/g' -i ruleset.conf
          '';

          services.fluent-bit.settings.pipeline.filters = lib.mkAfter [
            {
              name = "lua";
              match = "journal";
              script = parser;
              call = "egress_parse";
            }
            {
              name = "rewrite_tag";
              match = "journal";
              rule = "$egress ^.+$ egress false";
            }
            {
              name = "geoip2";
              match = "egress";
              database = geoDb;
              lookup_key = "dst";
              record = [
                "country dst %{country.iso_code}"
                "country_name dst %{country.names.en}"
              ];
            }
            {
              name = "lua";
              match = "egress";
              script = parser;
              call = "egress_geo_clean";
            }
          ];
        };

      opensnitch.nixos.services.opensnitch = {
        enable = true;
        settings = {
          DefaultAction = "allow";
          InterceptUnknown = false;
          Internal.FlushConnsOnStart = false;
          Server.Loggers = [
            {
              Name = "syslog";
              Format = "rfc5424";
              Tag = "opensnitch";
            }
          ];
        };
      };

      server.nixos.services.loki.configuration.limits_config.retention_stream = [
        {
          selector = ''{job="egress"}'';
          priority = 1;
          period = "720h";
        }
      ];
    };
  };
}
