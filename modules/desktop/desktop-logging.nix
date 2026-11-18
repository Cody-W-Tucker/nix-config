{
  # Desktop logging: the node exporter port is opened on tailscale0 so the NAS Prometheus can scrape it.
  den.aspects.desktop-logging = {
    nixos =
      { config, ... }:

      {
        # The shared node exporter is scraped by the NAS Prometheus over Tailscale.
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
          config.services.prometheus.exporters.node.port
        ];
      };
  };
}
