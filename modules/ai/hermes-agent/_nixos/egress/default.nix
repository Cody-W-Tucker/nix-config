# What the hermes user may reach. One policy covers every process it runs:
# the gateway, its MCP servers, cron jobs and the terminal sandbox (which
# shares the host network). The internet is open; this host, the LAN, the
# tailnet, IPv6 and SSH are closed except for the local services declared
# through codyos.hermes-agent.egress.
{
  config,
  lib,
  ...
}:

let
  cfg = config.codyos.hermes-agent.egress;
  inherit (config.services.hermes-agent) user;
  owner = config.codyos.site.user.name;
  bridge = import ../../_bridge/endpoints.nix;
  ports = lib.concatMapStringsSep ", " toString;
in
{
  options.codyos.hermes-agent.egress = {
    loopbackPorts = lib.mkOption {
      type = with lib.types; listOf port;
      default = [ ];
      description = "TCP ports on IPv4 loopback that Hermes may connect to.";
    };
  };

  config = {
    # DNS goes to the local resolver.
    codyos.hermes-agent.egress.loopbackPorts = [ 53 ];

    networking.nftables.tables.hermes-egress = {
      family = "inet";
      content = ''
        set private4 {
          type ipv4_addr; flags interval
          elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16,
                       172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255/32 }
        }

        chain output {
          type filter hook output priority filter; policy accept;
          # Loopback is not authentication: do not expose Cody's search to other users.
          ip daddr 127.0.0.1 tcp dport { ${
            ports [
              bridge.qmd.port
              bridge.deja.port
            ]
          } } meta skuid != { root, ${owner}, ${user} } reject with tcp reset
          meta skuid != ${user} return

          # The gateway/dashboard may reply to clients that connected inbound.
          ct direction reply ct state established accept
          ip daddr 127.0.0.1 tcp dport { ${ports (lib.unique cfg.loopbackPorts)} } accept
          ip daddr 127.0.0.1 udp dport 53 accept

          tcp dport 22 reject with tcp reset
          fib daddr type local reject
          ip daddr @private4 reject
          # The LAN's global IPv6 prefix cannot be told apart from the internet.
          meta nfproto ipv6 reject
        }
      '';
    };
    # The build-time ruleset check has no /etc/passwd entry for the hermes user.
    networking.nftables.preCheckRuleset = ''
      sed -e 's/skuid != ${user}/skuid != 65534/g' \
          -e 's/skuid != { root, ${owner}, ${user} }/skuid != { 0, 1000, 65534 }/g' -i ruleset.conf
    '';

    # Paths no Hermes process needs, closed for the units themselves.
    # tailscaled's socket dials any tailnet host and port (`tailscale nc`).
    systemd.services =
      lib.genAttrs
        [
          "hermes-agent"
          "hermes-backend"
        ]
        (_: {
          after = [ "nftables.service" ];
          requires = [ "nftables.service" ];
          serviceConfig.InaccessiblePaths = [
            "/home"
            "/root"
            "-/mnt"
            "-/data"
            "-/run/tailscale"
            "-/run/nscd"
            "-/run/ssh-unix-local"
            "-/run/postgresql"
            "-/run/docker.sock"
          ];
        });
  };
}
