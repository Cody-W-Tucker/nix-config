{ den, ... }:
let
  # Ports that are routine for these hosts; anything else trips the
  # "unusual egress port" alert. Tune here as false positives show up.
  routinePorts = [
    "22" # ssh / git
    "53" # dns
    "80"
    "123" # ntp
    "443"
    "853" # dns-over-tls
    "3478" # tailscale STUN
    "41641" # tailscale direct
    "21027" # syncthing discovery
    "22000" # syncthing
  ];
  # Tailscale reaches peers from its own port 41641 to whatever port the peer
  # got; those destination ports are arbitrary, so match on the source port.
  routineSourcePorts = [ "41641" ];

  # Grafana contact point (created in the Grafana UI) that egress alerts go to.
  receiver = "Discord";

  # Instant LogQL query → reduce → "> 0" threshold, the shape every egress
  # alert shares. groupBy splits notifications so each message names its
  # country/port/host instead of batching every instance into one (Discord
  # truncates messages at 2000 characters).
  lokiAlert =
    {
      uid,
      title,
      expr,
      summary,
      groupBy,
    }:
    {
      inherit uid title;
      notification_settings = {
        inherit receiver;
        group_by = [
          "alertname"
          "grafana_folder"
        ]
        ++ groupBy;
      };
      condition = "C";
      data = [
        {
          refId = "A";
          datasourceUid = "loki";
          relativeTimeRange = {
            from = 900;
            to = 0;
          };
          model = {
            refId = "A";
            inherit expr;
            queryType = "instant";
            editorMode = "code";
          };
        }
        {
          refId = "B";
          datasourceUid = "__expr__";
          model = {
            refId = "B";
            type = "reduce";
            expression = "A";
            reducer = "last";
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "B";
            conditions = [
              {
                evaluator = {
                  type = "gt";
                  params = [ 0 ];
                };
              }
            ];
          };
        }
      ];
      noDataState = "OK";
      execErrState = "Error";
      for = "0s";
      annotations.summary = summary;
      labels.feature = "egress-audit";
    };
in
{
  # Egress audit: record every new outbound connection, enrich it with the
  # destination country and ship it to Loki as job="egress".
  #
  #   egress-audit             every selecting host: nftables logs new connections
  #                            to non-private addresses (host and forwarded/container
  #                            traffic); Fluent Bit parses them, plus Unbound query
  #                            logs and OpenSnitch events, into the egress stream.
  #   egress-audit.opensnitch  per-process attribution (which program connected).
  #   egress-audit.server      the Loki host: 30-day retention and Grafana alerts.
  #
  # Shipping rides the logging.forward-* aspects (modules/observability/logging.nix).
  den.aspects.egress-audit.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Interpolation copies just this file to the store (toString would point
      # into the whole flake source).
      parser = "${./_egress-parse.lua}";
      geoDb = "${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb";
      logRule =
        family: set: prefix: flags:
        "ct state new ${family} daddr != @${set} limit rate 50/second burst 500 packets log prefix \"${prefix}: \" level info${flags}";
      # The local recursive resolver talks to authoritative servers all day;
      # its client queries are logged by Unbound instead (dns aspect).
      skipResolver = lib.optionalString config.services.unbound.enable ''
        meta l4proto { tcp, udp } th dport { 53, 853 } meta skuid unbound return
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

          chain output {
            type filter hook output priority filter + 10; policy accept;
            ${skipResolver}
            ${logRule "ip" "private4" "egress-out" " flags skuid"}
            ${logRule "ip6" "private6" "egress-out" " flags skuid"}
          }

          # Docker containers and other routed traffic never pass the output hook.
          chain forward {
            type filter hook forward priority filter + 10; policy accept;
            ${logRule "ip" "private4" "egress-fwd" ""}
            ${logRule "ip6" "private6" "egress-fwd" ""}
          }
        '';
      };
      # The build-time ruleset check has no /etc/passwd entry for the resolver user.
      networking.nftables.preCheckRuleset = lib.mkIf config.services.unbound.enable ''
        sed 's/skuid unbound/skuid root/g' -i ruleset.conf
      '';

      # Runs after the shared journal filters (logging.nix): parse, move to the
      # "egress" tag, then add the destination country.
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

  # Which program opened each connection. Log-only: unknown connections are
  # allowed without prompting; every decision goes to the journal (syslog
  # logger) and from there into the egress stream.
  den.aspects.egress-audit.opensnitch.nixos = {
    services.opensnitch = {
      enable = true;
      settings = {
        DefaultAction = "allow";
        InterceptUnknown = false;
        Server.Loggers = [
          {
            Name = "syslog";
            Format = "rfc5424";
            Tag = "opensnitch";
          }
        ];
      };
    };
  };

  # Loki-side retention and alerting for the egress stream. Alerts go to the
  # `receiver` contact point above, one notification per country/port/host.
  den.aspects.egress-audit.server.nixos = {
    services.loki.configuration.limits_config.retention_stream = [
      {
        selector = ''{job="egress"}'';
        priority = 1;
        period = "720h";
      }
    ];

    services.grafana.provision.alerting.rules.settings.groups = [
      {
        orgId = 1;
        name = "egress";
        folder = "Egress audit";
        interval = "15m";
        rules = [
          (lokiAlert {
            uid = "egress-new-country";
            title = "Egress to a new country";
            expr = ''count by (host, country) (count_over_time({job="egress", country=~".+"}[15m])) unless count by (host, country) (count_over_time({job="egress", country=~".+"}[30d] offset 15m))'';
            summary = "{{ $labels.host }} connected to {{ $labels.country }} for the first time in 30 days.";
            groupBy = [
              "host"
              "country"
            ];
          })
          (lokiAlert {
            uid = "egress-unusual-port";
            title = "Egress on an unusual port";
            expr = ''sum by (host, dport, proto) (count_over_time({job="egress", source="nft"} | json | dport != "" and dport !~ "^(${builtins.concatStringsSep "|" routinePorts})$" and sport !~ "^(${builtins.concatStringsSep "|" routineSourcePorts})$" [15m]))'';
            summary = "{{ $labels.host }} opened {{ $labels.proto }} connections to port {{ $labels.dport }}.";
            groupBy = [
              "host"
              "proto"
              "dport"
            ];
          })
          (lokiAlert {
            uid = "egress-volume-spike";
            title = "Egress connection spike";
            expr = ''sum by (host) (count_over_time({job="egress", source="nft"}[15m])) > 3 * (sum by (host) (count_over_time({job="egress", source="nft"}[7d] offset 15m)) / 672) and sum by (host) (count_over_time({job="egress", source="nft"}[15m])) > 500'';
            summary = "{{ $labels.host }} opened more than 3x its usual number of outbound connections in 15 minutes.";
            groupBy = [ "host" ];
          })
        ];
      }
    ];
  };
}
