{ config, ... }:

{
  # The shared node exporter is scraped by the NAS Prometheus over Tailscale.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
  ];
}
