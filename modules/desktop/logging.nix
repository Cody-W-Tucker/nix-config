{ config, ... }:

{
  # Monitoring configuration. The node exporter and journal shipping to the NAS
  # Loki are shared with every host (modules/system/logging.nix).
  services.prometheus = {
    enable = true;
    port = 9001;
  };

  # Node exporter: scraped by the NAS Prometheus over Tailscale.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
  ];
}
